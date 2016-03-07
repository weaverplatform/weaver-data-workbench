'use strict'

# Weaver Angular module
angular.module 'app',
  [
    # Angular core modules
    'ngAnimate'
    'ngTouch'
    'ngSanitize'

    # 3rd Party Modules
    'ui.router'                  # More advanced routing based on states
  ]


# Configuration
.config(($urlRouterProvider, $stateProvider) ->

  # Default route all to /
  $urlRouterProvider.otherwise('/')

  # Weaver app template
  $stateProvider
  .state 'main',
    template: ''
)

.factory('Weaver', ($window) ->
  new $window.Weaver('http://localhost:9487')
)

.run(($state, Weaver) ->
  
  console.log(Weaver)
  
  # Head to the main state
  $state.go('main')
)


