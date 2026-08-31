import android.os.SystemClock;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

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
  private final Map<Integer, Long> keyDownTimes = new HashMap<>();
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
      if (parts.length == 0 || parts[0].isEmpty()) continue;
      String actionName = parts[0].toUpperCase();
      if ("KEY".equals(actionName)) {
        bridge.handleKeyCommand(parts);
        continue;
      }
      if (parts.length < 3) continue;
      float x = Float.parseFloat(parts[1]);
      float y = Float.parseFloat(parts[2]);
      bridge.inject(actionName, x, y);
    }
  }

  private void handleKeyCommand(String[] parts) {
    String requestId = parts.length > 1 ? parts[1] : "-";
    try {
      if (parts.length < 5) throw new IllegalArgumentException("malformed_key_command");
      String actionName = parts[2].toUpperCase();
      int keyCode = Integer.parseInt(parts[3]);
      int metaState = Integer.parseInt(parts[4]);
      int repeatCount = parts.length > 5 ? Integer.parseInt(parts[5]) : 0;
      boolean result = injectKey(actionName, keyCode, metaState, repeatCount);
      writeKeyResult(requestId, result, result ? null : "inject_rejected");
    } catch (Exception error) {
      writeKeyResult(requestId, false, error.getMessage() == null ? "key_inject_failed" : error.getMessage());
    }
  }

  private boolean injectKey(String actionName, int keyCode, int metaState, int repeatCount) {
    switch (actionName) {
      case "DOWN":
        long downAt = SystemClock.uptimeMillis();
        keyDownTimes.put(keyCode, downAt);
        return injectKeyEvent(KeyEvent.ACTION_DOWN, downAt, keyCode, repeatCount, metaState);
      case "UP":
        long storedDownAt = keyDownTimes.containsKey(keyCode)
            ? keyDownTimes.remove(keyCode)
            : SystemClock.uptimeMillis();
        return injectKeyEvent(KeyEvent.ACTION_UP, storedDownAt, keyCode, 0, metaState);
      case "PRESS":
        long pressDownAt = SystemClock.uptimeMillis();
        boolean downResult = injectKeyEvent(KeyEvent.ACTION_DOWN, pressDownAt, keyCode, 0, metaState);
        boolean upResult = injectKeyEvent(KeyEvent.ACTION_UP, pressDownAt, keyCode, 0, metaState);
        return downResult && upResult;
      default:
        throw new IllegalArgumentException("unsupported_key_action");
    }
  }

  private boolean injectKeyEvent(int action, long downTime, int keyCode, int repeatCount, int metaState) {
    long eventTime = SystemClock.uptimeMillis();
    KeyEvent event = new KeyEvent(
        downTime,
        eventTime,
        action,
        keyCode,
        repeatCount,
        metaState,
        -1,
        0,
        0,
        InputDevice.SOURCE_KEYBOARD);
    try {
      Object result = injectInputEvent.invoke(inputManager, event, 2);
      return Boolean.TRUE.equals(result);
    } catch (Exception error) {
      return false;
    }
  }

  private void writeKeyResult(String requestId, boolean result, String error) {
    System.out.println("KEY_RESULT " + requestId + " " + result
        + (error == null ? "" : " " + error.replaceAll("\\s+", "_")));
    System.out.flush();
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
