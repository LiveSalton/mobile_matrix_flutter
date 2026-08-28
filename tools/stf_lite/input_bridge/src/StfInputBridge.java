import android.os.SystemClock;
import android.view.InputDevice;
import android.view.MotionEvent;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;

/**
 * Minimal persistent shell-side touch injector for devices where minitouch
 * cannot access /dev/input. The process keeps one MotionEvent downTime for a
 * whole gesture, unlike invoking `input motionevent` for every point.
 */
public final class StfInputBridge {
  private static final int DISPLAY_ID = 0;
  private static final float PRESSURE_DOWN = 1.0f;
  private static final float PRESSURE_UP = 0.0f;

  private final Method injectInputEvent;
  private final Object inputManager;
  private long downTime;
  private boolean gestureActive;

  private StfInputBridge() throws Exception {
    Class<?> inputManagerClass = Class.forName("android.hardware.input.InputManagerGlobal");
    Method getInstance = inputManagerClass.getDeclaredMethod("getInstance");
    getInstance.setAccessible(true);
    inputManager = getInstance.invoke(null);
    injectInputEvent = inputManagerClass.getDeclaredMethod(
        "injectInputEvent", android.view.InputEvent.class, int.class);
    injectInputEvent.setAccessible(true);
  }

  public static void main(String[] args) throws Exception {
    StfInputBridge bridge = new StfInputBridge();
    BufferedReader input = new BufferedReader(new InputStreamReader(System.in));
    String line;
    while ((line = input.readLine()) != null) {
      String[] parts = line.trim().split("\\s+");
      if (parts.length < 3) continue;
      String actionName = parts[0].toUpperCase();
      float x = Float.parseFloat(parts[1]);
      float y = Float.parseFloat(parts[2]);
      bridge.inject(actionName, x, y);
    }
  }

  private void inject(String actionName, float x, float y) throws Exception {
    int action;
    float pressure;
    switch (actionName) {
      case "DOWN":
        action = MotionEvent.ACTION_DOWN;
        pressure = PRESSURE_DOWN;
        downTime = SystemClock.uptimeMillis();
        gestureActive = true;
        break;
      case "MOVE":
        if (!gestureActive) return;
        action = MotionEvent.ACTION_MOVE;
        pressure = PRESSURE_DOWN;
        break;
      case "UP":
        if (!gestureActive) return;
        action = MotionEvent.ACTION_UP;
        pressure = PRESSURE_UP;
        break;
      case "CANCEL":
        if (!gestureActive) return;
        action = MotionEvent.ACTION_CANCEL;
        pressure = PRESSURE_UP;
        break;
      default:
        return;
    }

    long eventTime = SystemClock.uptimeMillis();
    MotionEvent.PointerProperties[] properties = {
        new MotionEvent.PointerProperties()
    };
    properties[0].id = 0;
    properties[0].toolType = MotionEvent.TOOL_TYPE_FINGER;

    MotionEvent.PointerCoords[] coordinates = {
        new MotionEvent.PointerCoords()
    };
    coordinates[0].setAxisValue(MotionEvent.AXIS_X, x);
    coordinates[0].setAxisValue(MotionEvent.AXIS_Y, y);
    coordinates[0].setAxisValue(MotionEvent.AXIS_PRESSURE, pressure);
    coordinates[0].setAxisValue(MotionEvent.AXIS_SIZE, 1.0f);

    MotionEvent event = MotionEvent.obtain(
        downTime,
        eventTime,
        action,
        1,
        properties,
        coordinates,
        0,
        0,
        1.0f,
        1.0f,
        0,
        0,
        InputDevice.SOURCE_TOUCHSCREEN,
        DISPLAY_ID,
        0,
        MotionEvent.CLASSIFICATION_NONE);
    try {
      Object result = injectInputEvent.invoke(inputManager, event, 2);
      System.out.println("INJECT action=" + actionName + " x=" + x + " y=" + y
          + " result=" + result);
      System.out.flush();
    } finally {
      event.recycle();
    }
    if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
      gestureActive = false;
    }
  }
}
