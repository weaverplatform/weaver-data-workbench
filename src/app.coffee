'use strict'

# Weaver Angular module
angular.module 'app',
  [
    # Angular core modules
    'ngAnimate'
    'ngTouch'
    'ngSanitize'

    # 3rd Party Modules
    'ui.router'       # More advanced routing based on states
    'ui.bootstrap'    # Angular Dialog
    'treeControl'     # Tree of objects
    'xeditable'       # In place editing of fields
  ]


# Configuration
.config(($urlRouterProvider, $stateProvider) ->

  # Weaver app template
  $stateProvider

  .state 'app',
    url: '/:dataset',
    templateUrl: 'src/app.ng.html'
    controller: 'AppCtrl'
    resolve: {
      dataset: (Weaver, $stateParams) ->
        Weaver.get($stateParams.dataset, {eagerness: -1})
    }
)

.factory('Weaver', ($window) ->
  $window.weaver = new $window.Weaver().connect('https://weaver-server.herokuapp.com')
  $window.weaver
)

.run(($state, editableOptions, $location, $window) ->

  # Configure xeditable using bootstrap 3 theme and by default not showing the submit/cancel buttons
  editableOptions.theme = 'bs3'
  editableOptions.buttons = 'no'
  
  # Random generate dataset id if not given
  if $location.path() is '' || $location.path() is '/' 
    $location.path('/' + $window.cuid())
)


.filter('toArray', ->
  (input) ->
    (object for key, object of input)
)


.controller 'AppCtrl', ($rootScope, $scope, Weaver, $window, TableService, $uibModal, dataset, $timeout) ->
    
  # Init objects
  if not dataset.objects?
    dataset.objects = Weaver.collection()
    dataset.$push('objects')

  $scope.dataset = dataset
  $scope.allObjects = []
  
  readAllObjects = ->
    $scope.allObjects = (object for id, object of $scope.dataset.objects.$links())

  readAllObjects()

  # Adds a new object to the dataset
  $scope.addObject = ->
    
    # Create object and add to dataset
    object = Weaver.add({name: 'Unnamed'}, 'object')
    $scope.dataset.objects.$push(object)
    
    # Create first annotation and property
    object.annotations = Weaver.collection()
    object.$push('annotations')

    annotation = Weaver.add({label: 'has name'}, 'annotation')
    annotation.properties = Weaver.collection()
    annotation.$push('properties')
    object.annotations.$push(annotation)

    property = Weaver.add({value: 'Unnamed'}, 'property')
    annotation.properties.$push(property)
    
    # Open by default
    $scope.openObjects.push(object)
    $scope.activeObject = object
    readAllObjects()
    
    
  $scope.addColumn = (object) ->
    annotation = Weaver.add({label: 'unnamed'}, 'annotation')
    object.annotations.$push(annotation)
    object.$refresh = true
    $timeout((-> object.$refresh = false), 1)
    


  $scope.activeTree = 'data'
  $scope.selectView = (viewName) ->
    $scope.activeTree = viewName



  createSubTree = (level, width, prefix) ->

    if (level > 0)
      res = []
      for  i in [1 .. width]
        res.push({
          "label": "Collection " + prefix + i,
          "id": "id" + prefix + i,
          "i": i,
          "children": createSubTree(level - 1, width, prefix + i + ".")
        })

      return res
    else
      return []

  $scope.objectTreeOptions = {
    injectClasses: {
      ul: "a1"
      li: "a2"
      liSelected: "a7"
      iExpanded: "a5"
      iCollapsed: "a4"
      iLeaf: "a4"
      label: "a6"
      labelSelected: "a8"
    }
  }

  $scope.collectionTreeOptions = {
    injectClasses: {
      ul: "b1"
      li: "b2"
      liSelected: "b7"
      iExpanded: "b3"
      iCollapsed: "b4"
      iLeaf: "b5"
      label: "b6"
      labelSelected: "b8"
    }
  }


  $scope.openObjects = []
  $scope.activeObject = $scope.openObjects[0]

  $scope.openObject = (object) ->
    $scope.openObjects.push(object)
    $scope.activateObject(object)

  $scope.activateObject = (object) ->
    $scope.activeObject = object

  $scope.closeObject = (object) ->

    location = $scope.openObjects.indexOf(object)
    if location > -1

      # make next active
      if object is $scope.activeObject
        if $scope.openObjects.length > 0
          nextLocation = (location + 1) % ($scope.openObjects.length)
          $scope.activeObject = $scope.openObjects[nextLocation]

      # remove
      $scope.openObjects.splice(location, 1)


  $scope.datatree = createSubTree(2, 4, "")
  $scope.collectiontree = createSubTree(1, 4, "")


  $scope.lastClicked = null;

  $scope.buttonClick = ($event, node) ->
    $scope.lastClicked = node
    $scope.message = node.label
    
    $scope.openObjects.push(node) if $scope.openObjects.indexOf(node) is -1
    $scope.activeObject = node
    
    $event.stopPropagation()

  $scope.showSelected = (sel) ->
    $scope.message = sel.label
    $scope.selectedNode = sel





  updateTableHeaders = ->
    table.updateSettings({
      columns:            tableService.getColumns()
      colHeaders:         tableService.getColumnsHeader()
    })

  updateTableData = ->
    table.updateSettings({
      data:               tableService.data
    })





.directive('objectTable', (TableService, $uibModal) ->
  {
    restrict: 'E'
    scope: {
      object: '='
    }
    link: (scope, element) ->



      openAddColumnModal = (objectToUpdate) ->
        $uibModal.open({
          animation: false
          templateUrl: 'addColumn.ng.html'
          controller: ($scope) ->
            $scope.title = 'Add column'
            $scope.columnName = 'nameless'
            $scope.columnType = 'string'
    
            $scope.ok = ->
    
            # post
              annotationName = $scope.columnName
              if(annotationName? and annotationName isnt '')
    
                annotation = Weaver.add({label: annotationName}, 'annotation')
                annotation.properties = Weaver.collection()
                annotation.$push('properties')
                objectToUpdate.object.annotations.$push(annotation)
    
    
              $scope.$close();
    
            $scope.cancel = ->
              # clean
              $scope.$close();
    
          size: 'sm'
        })


      tableElement = element[0]
      tableElement.addEventListener('click', (event) ->
        # The click event would otherwise close the xeditable plugin for some reason
        if event.target.classList? and event.target.classList[0] is 'edit-attribute'
          event.stopPropagation()

      , true)      
      
      tableElement.addEventListener('mousedown', (event) ->
        # The click event would otherwise close the xeditable plugin for some reason
        if event.target.classList? and event.target.classList[0] is 'edit-attribute'
          event.stopPropagation()
          openAddColumnModal(object)

      , true)

      object = scope.object
      tableService = new TableService(object)

      containerDiv = document.createElement("div")
      element[0].appendChild(containerDiv)
      
      getColumns = ->
        tableService.getColumns()
        
      getHeaders = ->
        names   = tableService.getColumnsHeader()
        (getHTMLHeader(name) for name in names)
        
      getHTMLHeader = (name) ->
        """
          <span class='table-header-title btn-stick'>#{name}</span>
          <button style="padding: 0; margin-top: 1px; margin-left: 3px;" class='btn btn-default btn-xs tbl-header-button' id='#{name}'>
            <i style='padding: 3px 5px;' class='edit-attribute fa fa-pencil'></i>
          </button>
        """
        
    
      table = new Handsontable(containerDiv, {

        data:               tableService.data
        columns:            getColumns()
        colHeaders:         getHeaders()
        rowHeaders:         false

        minSpareRows:       1
        minSpareCols:       1

        autoColumnSize:     true
        columnSorting:      false
        manualColumnFreeze: false
        contextMenu:        true
        mergeCells:         false
        manualColumnMove:   false
        manualRowMove:      false

        afterChange: (changes, source) ->

          if changes
            for change in changes

              changeRow = change[0]
              changeAnnotationId = change[1]
              changeOldValue = change[2]
              changeNewValue = change[3]

              annotation = tableService.getAnnotationById(changeAnnotationId)
              property = tableService.getProperty(changeRow, changeAnnotationId)

              # annotation should exist
              if not annotation?
                console.error('annotation not found for '+changeAnnotationId)
                return

              if source is 'edit'

                # delete
                if changeNewValue is ''
                  console.log('delete') # TODO
                  tableService.removeProperty(annotation, property)

                # update existing property
                else if property? and changeNewValue isnt changeOldValue
                  console.log('edit')
                  tableService.updateProperty(property, changeNewValue)

                # create new property
                else if not property?
                  console.log('new property')
                  table.setDataAtRowProp(changeRow, changeAnnotationId, '', 'override')
                  newRow = tableService.newProperty(annotation, changeNewValue)
                  table.setDataAtRowProp(newRow, changeAnnotationId, changeNewValue, 'override')

    })
  }
)










.factory('TableService', (Weaver) ->


  class TableService
    
    constructor: (@object) ->
      @annotationMap = {}
      @propertyMap = {}
      @data = []

      @nextCol = 0
      @nextRow = {}
    
      for id, annotation of @object.annotations.$links()
        @addAnnotation(id, annotation)

    getColumns: ->
      ({data: id} for id of @object.annotations.$links())

    getColumnsHeader: ->
      (annotation.label for id, annotation of @object.annotations.$links())

    addAnnotation: (id, annotation) ->

      @annotationMap[id] = annotation

      if not @nextRow[id]?
        @nextRow[id] = 0

      if annotation.properties?
        for propertyId, property of annotation.properties.$links()
          if property.value?
            @addProperty(id, property)

      @nextCol++


    newAnnotation: (annotationName) ->

      annotation = Weaver.add({label: annotationName}, 'annotation')
      annotation.properties = Weaver.collection()
      annotation.$push('properties')
      @object.annotations.$push(annotation)

      @addAnnotation(annotation.$id(), annotation)

    # returns row where the property is placed
    addProperty: (annotationId, property) ->

      while not @data[@nextRow[annotationId]]?
        @data.push({})

      # set data
      @data[@nextRow[annotationId]][annotationId] = property.value

      # set property
      if(not @propertyMap[@nextRow[annotationId]]?)
        @propertyMap[@nextRow[annotationId]] = {}
      @propertyMap[@nextRow[annotationId]][annotationId] = property

      @nextRow[annotationId] += 1
      @nextRow[annotationId]-1

    # returns row where the property is placed
    newProperty: (annotation, value) ->

      property = Weaver.add({value: value}, 'property')
      if not annotation.properties?
        annotation.properties = Weaver.collection()
        annotation.$push('properties')
        
      annotation.properties.$push(property)

      @addProperty(annotation.$id(), property)


    updateProperty: (property, value) ->
      property.$push('value', value)


    removeProperty: (annotation, property) ->
      if property?
        property.$push('value', '' )       # TODO



    getAnnotationById: (id) ->
      if(@annotationMap[id]?)
        return @annotationMap[id]
      null



    getProperty: (row, id) ->
      if(@propertyMap[row]?)
        if(@propertyMap[row][id]?)
          return @propertyMap[row][id]
      null


)