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

.constant('SERVER_ADDRESS', 'https://weaver-server.herokuapp.com')

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

.factory('Weaver', ($window, SERVER_ADDRESS) ->
  $window.weaver = new $window.Weaver().connect(SERVER_ADDRESS)
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


.controller 'AppCtrl', ($rootScope, $scope, Weaver, $window, TableService, $uibModal, dataset, $timeout, SERVER_ADDRESS) ->
    
  # Init objects
  if not dataset.objects?
    dataset.objects = Weaver.collection()
    dataset.$push('objects')

  $scope.downloadTurtle = ->
    url = SERVER_ADDRESS + "/turtle?id=" + $scope.dataset.$id()
    $window.location.href = url
    return true

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

    
    # Create first annotation
    object.annotations = Weaver.collection()
    object.$push('annotations')

    annotation = Weaver.add({label: 'has name', celltype: 'string'}, 'annotation')
    object.annotations.$push(annotation)


    # Create first property
    object.properties = Weaver.collection()
    object.$push('properties')



    property = Weaver.add({predicate: 'has name', value: 'Unnamed'}, 'property')
    property.$push('subject', object)
    property.$push('annotation', annotation)
    object.properties.$push(property)


    
    # Open by default
    $scope.openObjects.push(object)
    $scope.activeObject = object
    readAllObjects()
    
    
  $scope.addColumn = (object) ->
    annotation = Weaver.add({label: 'unnamed', celltype: 'string'}, 'annotation')
    object.annotations.$push(annotation)
    object.$refresh = true
    $timeout((-> object.$refresh = false), 1)

  $scope.deleteObject = (object) ->
    $scope.closeObject(object)
    location = $scope.allObjects.indexOf(object)
    $scope.allObjects.splice(location, 1)
    $scope.dataset.objects.$remove(object)
    object.$destroy()
    


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











.directive('objectTable', (TableService, $uibModal, $timeout) ->
  {
    restrict: 'E'
    link: (scope, element) ->

      object = scope.object
      tableService = new TableService(object)

      editColumnModal = (annotationId) ->
        annotation = tableService.getAnnotationById(annotationId)

        $uibModal.open({
          animation: false
          templateUrl: 'addColumn.ng.html'
          controller: ($scope) ->
            $scope.title = 'Add column'
            $scope.columnName = annotation.label
            $scope.columnType = annotation.celltype



            $scope.ok = ->


              # post
              if($scope.columnName? and $scope.columnName isnt '')
                tableService.updateAnnotation(annotationId, {label: $scope.columnName, celltype: $scope.columnType})
#                table.updateSettings({
#                  colHeaders: getHeaders()
#                })
#                table.render()

                object.$refresh = true
                $timeout((-> object.$refresh = false), 1)
    
              $scope.$close();
    
            $scope.cancel = ->
              # clean
              $scope.$close();
    
          size: 'sm'
        })


      tableElement = element[0]

      tableElement.addEventListener('mousedown', (event) ->


        if event.target.classList? and event.target.classList[0] is 'edit-attribute'
          event.stopPropagation()
          headerDivId = $(event.target).parent()[0].id
          annotationId = headerDivId.substr(7)
          editColumnModal(annotationId)

      , true)

#      tableElement.addEventListener('mousedown', (event) ->
#
#
#        if event.target.classList? and event.target.classList[0] is 'edit-attribute'
#          event.stopPropagation()
#          headerDivId = $(event.target).parent()[0].id
#          annotationId = headerDivId.substr(7)
#          editColumnModal(annotationId)
#
#      , true)



      containerDiv = document.createElement("div")
      element[0].appendChild(containerDiv)



      findObjectByName = (name) ->
        for object in scope.allObjects
          if object.name is name
            return object

        null


      getColumns = ->
        updateColumn = (column) ->

          annotationId = column.data
          annotation = tableService.getAnnotationById(annotationId)


          if annotation.celltype is 'string'
            column = {
              data: annotationId
              type: 'text'
            }
          if annotation.celltype is 'object'
            column = {
              data: annotationId
              type: 'autocomplete'
              strict: false
              source: (query, process) ->

                candidates = (object.name for id, object of scope.dataset.objects.$links())
                process(candidates)
            }
          column

        (updateColumn(column) for column in tableService.getColumns())



      getHeaders = ->
        headers   = tableService.getColumnsHeader()
        (getHTMLHeader(header) for header in headers)
        
      getHTMLHeader = (header) ->
        """
          <span class='table-header-title btn-stick'>#{header.name}</span>
          <button style="padding: 0; margin-top: 1px; margin-left: 3px;" class='btn btn-default btn-xs tbl-header-button' id='header_#{header.annotationId}'>
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
                  console.log('delete')
                  tableService.removeProperty(property)

                # update existing property
                else if property? and changeNewValue isnt changeOldValue
                  console.log('edit')


                  if annotation.celltype is 'string'
                    newRow = tableService.updateProperty(property, changeNewValue)

                  else if annotation.celltype is 'object'
                    toObject = findObjectByName(changeNewValue)
                    newRow = tableService.updateProperty(property, toObject)


                # create new property
                else if not property?
                  console.log('new property')

                  table.setDataAtRowProp(changeRow, changeAnnotationId, '', 'override')
                  if annotation.celltype is 'string'
                    newRow = tableService.newProperty(annotation, changeNewValue)

                  else if annotation.celltype is 'object'
                    toObject = findObjectByName(changeNewValue)
                    newRow = tableService.newProperty(annotation, toObject)

                  else
                    return
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

      for id, property of @object.properties.$links()
        annotation = property.annotation
        if annotation?
          @addProperty(annotation, property)

    getColumns: ->
      ({data: id} for id of @object.annotations.$links()).sort((a,b) -> a.data.localeCompare(b.data))

    getColumnsHeader: ->
      ({name:annotation.label, annotationId:id} for id, annotation of @object.annotations.$links()).sort((a,b) -> a.annotationId.localeCompare(b.annotationId))

    addAnnotation: (id, annotation) ->

      @annotationMap[id] = annotation

      if not @nextRow[id]?
        @nextRow[id] = 0

      @nextCol++


    newAnnotation: (fields) ->

      annotation = Weaver.add(fields, 'annotation')
      @object.annotations.$push(annotation)

      @addAnnotation(annotation.$id(), annotation)


    updateAnnotation: (annotationId, fields) ->

      annotation = @getAnnotationById(annotationId)
      if(annotation?)
        for key, value of fields
          annotation.$push(key, value)



    # returns row where the property is placed
    addProperty: (annotation, property) ->

      annotationId = annotation.$id()

      if not @data[@nextRow[annotationId]]?
        @data.push({})

      # set data
      if annotation.celltype is 'string'
        @data[@nextRow[annotationId]][annotationId] = property.value
      if annotation.celltype is 'object'
        @data[@nextRow[annotationId]][annotationId] = property.object.name

      # set property
      if(not @propertyMap[@nextRow[annotationId]]?)
        @propertyMap[@nextRow[annotationId]] = {}
      @propertyMap[@nextRow[annotationId]][annotationId] = property

      @nextRow[annotationId] += 1
      @nextRow[annotationId]-1

    # returns row where the property is placed
    newProperty: (annotation, value) ->

      if annotation.celltype is 'string'
        property = Weaver.add({predicate: annotation.label, value: value}, 'property')
        property.$push('subject', @object)
        property.$push('annotation', annotation)
      if annotation.celltype is 'object'
        property = Weaver.add({predicate: annotation.label}, 'property')
        property.$push('subject', @object)
        property.$push('object', value)
        property.$push('annotation', annotation)

      if not property?
        return

      if not @object.properties?
        @object.properties = Weaver.collection()
        @object.$push('properties')

      @object.properties.$push(property)

      @addProperty(annotation, property)


    updateProperty: (property, value) ->

      annotation = property.annotation
      if annotation.celltype is 'string'
        property.$push('value', value)
      if annotation.celltype is 'object'
        property.$push('object', value)



    removeProperty: (property) ->
      if property?
        if @object.properties?
          @object.properties.$remove(property)
        property.$destroy()



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
.directive('weaverTrashbutton', ($compile, $timeout) ->
  restrict: 'E'
  confirmed: false
  scope: {
    deleteObject: '=object'
    deleteAction: '&action'
  }
  link: (scope, element, attrs) ->

    confirmed = false

    element.on('mousedown', (event) ->

      event.preventDefault()

      if not confirmed
        confirmed = true
        element.addClass('confirmed')
        $timeout((->
          confirmed = false
          element.removeClass('confirmed')
        ), 5000)
      else
        confirmed = false
        element.removeClass('confirmed')
        scope.deleteAction()
    )
)