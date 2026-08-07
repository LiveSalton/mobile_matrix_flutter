'use strict'

module.exports = function createTrustedLocalAuth(options, dbapi) {
  var localUser = options.localUser

  return function trustedLocalAuth(req, res, next) { // eslint-disable-line no-unused-vars
    dbapi.saveUserAfterLogin({
      name: localUser.name
    , email: localUser.email
    , ip: req.ip
    })
      .then(function() {
        return dbapi.loadUser(localUser.email)
      })
      .then(function(user) {
        if (!user) {
          throw new Error('Trusted local STF user could not be loaded')
        }

        req.session.jwt = {
          name: localUser.name
        , email: localUser.email
        }
        req.sessionOptions.httpOnly = false
        req.user = user
        next()
      })
      .catch(next)
  }
}
