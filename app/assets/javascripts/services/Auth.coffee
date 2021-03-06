#app = angular.module 'thms.services'
#
#app.factory 'Auth', [
#    '$rootScope', '$http', 'localStorageService', '$q', ($rootScope, $http, ls, $q) ->
#        new class Auth
#            constructor: ->
#                @setAccessToken ls.get 'access-token'
#                @setCurrentUser ls.get 'current-user'
#
#            setCurrentUser: (user) ->
#                return unless user
#                ls.set 'current-user', user
#                @currentUser = user
#
#            setAccessToken: (token) ->
#                return unless token
#                ls.set 'access-token', token
#                @accessToken = token
#                $http.defaults.headers.common['Authorization'] = "Bearer #{@accessToken}"
#
#            wipeData: ->
#                @currentUser = undefined
#                @accessToken = undefined
#                @currentlyMasquerading = false
#                delete $http.defaults.headers.common['EH-Masquerading-As']
#                delete $http.defaults.headers.common['Authorization']
#                ls.set 'access-token', null
#                ls.set 'current-user', null
#
#            login: (details = {}) ->
#                $http.post '/api/v2/sessions', details
#                    .success (result, status, headers) =>
#                        @setAccessToken headers('x-set-auth-token')
#                        @setCurrentUser result.data
#                        $rootScope.$broadcast 'event:auth-logged-in', result.data
#                    .error (response) =>
#                        $rootScope.$broadcast 'event:auth-login-invalid', response
#
#
#            logout: () ->
#                $http.delete '/api/v2/sessions'
#                    .then (response) =>
#                        @wipeData()
#                        $rootScope.$broadcast 'event:auth-logged-out'
#
#            checkLoggedIn: ->
#                deferred = $q.defer()
#
#                deferred.reject unless @currentUser
#
#                $http.get '/api/v2/auth/check'
#                    .then (response, status) =>
#                        @setCurrentUser response.data
#                        deferred.resolve response.data
#                    .catch (response) -> deferred.reject response
#
#                deferred.promise
#
#
#            startMasquerading: (id) ->
#                deferred = $q.defer()
#
#                $http.defaults.headers.common['EH-Masquerading-As'] = id
#
#                $http.get '/api/v2/masquerading/current'
#                    .then (response) =>
#                        @setCurrentUser response.data
#                        @currentlyMasquerading = true
#                        console.warn "Masquerading As #{response.data.email}"
#                        deferred.resolve(response.data)
#                    .catch (response) =>
#                        deferred.reject(response)
#                        @stopMasquerading()
#
#                deferred.promise
#
#            stopMasquerading: ->
#                delete $http.defaults.headers.common['EH-Masquerading-As']
#                @currentlyMasquerading = false
#                @checkLoggedIn()
#                $rootScope.$broadcast 'event:redirect-home'
#
#    ]


app = angular.module 'thms.services'

app.service 'Auth', [
    '$rootScope', '$http', '$q', '$localForage', ($rootScope, $http, $q, $localForage) ->
        new class Auth

            constructor: ->
                @initialized = false

            populateLocalData: ->
                deferred = $q.defer()

                authTokenPromise = $localForage.getItem 'authToken'
                currentUserPromise = $localForage.getItem 'currentUser'

                $q.all [authTokenPromise, currentUserPromise]
                .then (results) =>
                    @setAuthToken results[0]
                    @setCurrentUser results[1]
                    @initialized = true
                    deferred.resolve 'YAY!'
                .catch (error) =>
                    @initialized = true
                    deferred.reject error

                deferred.promise

            setAuthToken: (token) ->
                return unless token
                @authToken = token
                $http.defaults.headers.common['Authorization'] = "Bearer #{token}"
                $localForage.setItem 'authToken', token

            setCurrentUser: (data) ->
                return unless data
                @currentUser = data
                $localForage.setItem 'currentUser', data

            checkLoggedIn: ->
                deferred= $q.defer()

                @populateLocalData()
                .then =>
                    deferred.reject 'No Auth Token' unless @authToken

                    $http.get '/api/v2/sessions'
                    .then (results) =>
                        @setCurrentUser results.data
                        deferred.resolve results.data
                    .catch (error) =>
                        @clearLocalData()
                        deferred.reject 'Invalid Auth Token'
                .catch (error) =>
                    deferred.reject 'blah blah bad'

                deferred.promise

            clearLocalData: ->
                deferred = $q.defer()

                $localForage.clear()
                .then =>
                    @authToken = undefined
                    @currentUser = undefined
                    @currentlyMasquerading = false
                    delete $http.defaults.headers.common['EH-Masquerading-As']
                    delete $http.defaults.headers.common['Authorization']
                    deferred.resolve 'Yay, Data is cleared!'
                .catch (error) ->
                    deferred.reject 'Something went wrong clearing data'

                deferred.promise

            login: (data) ->
                deferred = $q.defer()

                $http.post 'api/v2/sessions', data
                .then (response) =>
                    if response.status is 201
                        # Save the authentication token
                        @setAuthToken response.headers('x-set-auth-token')
                        @setCurrentUser response.data

                        deferred.resolve response.data
                .catch (error) =>
                  deferred.reject error

                deferred.promise


            logout: ->
                @clearLocalData().then -> $rootScope.$broadcast 'Auth::loggedOut'

            startMasquerading: (id) ->
                deferred = $q.defer()

                $http.defaults.headers.common['EH-Masquerading-As'] = id

                $http.get '/api/v2/masquerading/current'
                    .then (response) =>
                        @setCurrentUser response.data
                        @currentlyMasquerading = true
                        deferred.resolve(response.data)
                    .catch (response) =>
                        deferred.reject(response)
                        @stopMasquerading()

                deferred.promise

            stopMasquerading: ->
                delete $http.defaults.headers.common['EH-Masquerading-As']
                @currentlyMasquerading = false
                @checkLoggedIn()
                $rootScope.$broadcast 'event:redirect-home'
]