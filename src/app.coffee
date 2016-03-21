'use strict'

# Weaver Angular module
angular.module 'weaver',
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


.controller 'AppCtrl', ($rootScope, $scope, Weaver, $window, ObjectTableService, CollectionTableService, $uibModal, dataset, $timeout, SERVER_ADDRESS) ->
    
  # Init objects
  if not dataset.objects?
    dataset.objects = Weaver.collection()
    dataset.$push('objects')
    dataset.collections = Weaver.collection()
    dataset.$push('collections')

  $scope.downloadTurtle = ->
    url = SERVER_ADDRESS + "/turtle?id=" + $scope.dataset.$id()
    $window.location.href = url
    return true

  $scope.dataset = dataset
  $scope.allObjects = []

  readAllObjects = ->
    $scope.allObjects = (object for id, object of $scope.dataset.objects.$links())

  readAllObjects()


  $scope.allCollections = []

  readAllCollections = ->
    $scope.allCollections = (collection for id, collection of $scope.dataset.collections.$links())

  readAllCollections()

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
    $scope.openTabs.push(object)
    $scope.activeTab = object
    readAllObjects()
    readAllCollections()

  # Adds a new object to the dataset
  $scope.addCollection = ->

    # Create object and add to dataset
    collection = Weaver.add({name: 'Unnamed'}, 'collection')
    $scope.dataset.collections.$push(collection)


    # Create filters collection
    collection.filters = Weaver.collection()
    collection.$push('filters')
    filter = Weaver.add({label: 'has name', predicate:'hasName', celltype: 'string'}, 'filter')
    collection.filters.$push(filter)

    # Create objects set
    collection.objects = Weaver.collection()
    collection.$push('objects')





    # Open by default
    $scope.openTabs.push(collection)
    $scope.activeTab = collection
    readAllObjects()
    readAllCollections()

    
  $scope.addColumn = (entity) ->

    if entity.$type() is 'object'

      annotation = Weaver.add({label: 'unnamed', celltype: 'string'}, 'annotation')
      entity.annotations.$push(annotation)
      entity.$refresh = true
      $timeout((-> entity.$refresh = false), 1)

    if entity.$type() is 'collection'

      filter = Weaver.add({label: 'unnamed', predicate:'unnamed', celltype: 'string'}, 'filter')
      entity.filters.$push(filter)
      entity.$refresh = true
      $timeout((-> entity.$refresh = false), 1)

  $scope.deleteObject = (object) ->
    $scope.closeTab(object)
    location = $scope.allObjects.indexOf(object)
    $scope.allObjects.splice(location, 1)
    $scope.dataset.objects.$remove(object)
    object.$destroy()

  $scope.deleteCollection = (collection) ->
    $scope.closeTab(collection)
    location = $scope.allCollections.indexOf(collection)
    $scope.allCollections.splice(location, 1)
    $scope.dataset.collections.$remove(collection)
    collection.$destroy()
    


  $scope.activeTree = 'data'
  $scope.selectView = (viewName) ->
    $scope.activeTree = viewName





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


  $scope.openTabs = []
  $scope.activeTab = $scope.openTabs[0]

  $scope.openTab = (entity) ->
    $scope.openTabs.push(entity)
    $scope.activateTab(entity)

  $scope.activateTab = (entity) ->
    $scope.activeTab = entity

  $scope.closeTab = (entity) ->

    location = $scope.openTabs.indexOf(entity)
    if location > -1

      # make next active
      if entity is $scope.activeTab
        if $scope.openTabs.length > 0
          nextLocation = (location + 1) % ($scope.openTabs.length)
          $scope.activeTab = $scope.openTabs[nextLocation]

      # remove
      $scope.openTabs.splice(location, 1)






  $scope.lastClicked = null;

  $scope.buttonClick = ($event, node) ->
    $scope.lastClicked = node
    $scope.message = node.label
    
    $scope.openTabs.push(node) if $scope.openTabs.indexOf(node) is -1
    $scope.activeTab = node
    
    $event.stopPropagation()

  $scope.showSelected = (sel) ->
    $scope.message = sel.label
    $scope.selectedNode = sel











.directive('objectTable', (ObjectTableService, $uibModal, $timeout) ->
  {
    restrict: 'E'
    link: (scope, element) ->

      object = scope.entity
      objectTableService = new ObjectTableService(object)

      editColumnModal = (annotationId) ->
        annotation = objectTableService.getAnnotationById(annotationId)

        $uibModal.open({
          animation: false
          templateUrl: 'addAnnotation.ng.html'
          controller: ($scope) ->

            $scope.title = 'Add column'
            $scope.columnName = annotation.label
            $scope.columnType = annotation.celltype

            $scope.ok = ->


              # post
              if($scope.columnName? and $scope.columnName isnt '')

                fields = {label: $scope.columnName, celltype: $scope.columnType}

                objectTableService.updateAnnotation(annotationId, fields)

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
#        if event.altKey
#          event.stopPropagation()
#          objectName = $(event.target)[0].innerText
#          foundObject = findObjectByName(objectName)
#          if foundObject?
#            scope.openTab(foundObject)
#
#
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
          annotation = objectTableService.getAnnotationById(annotationId)


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

        (updateColumn(column) for column in objectTableService.getColumns())



      getHeaders = ->
        headers   = objectTableService.getColumnsHeader()
        (getHTMLHeader(header) for header in headers)
        
      getHTMLHeader = (header) ->
        """
          <span class='table-header-title btn-stick'>#{header.name}</span>
          <button style="padding: 0; margin-top: 1px; margin-left: 3px;" class='btn btn-default btn-xs tbl-header-button' id='header_#{header.annotationId}'>
            <i style='padding: 3px 5px;' class='edit-attribute fa fa-pencil'></i>
          </button>
        """
        
    
      table = new Handsontable(containerDiv, {

        data:               objectTableService.data
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

              annotation = objectTableService.getAnnotationById(changeAnnotationId)
              property = objectTableService.getProperty(changeRow, changeAnnotationId)

              # annotation should exist
              if not annotation?
                console.error('annotation not found for '+changeAnnotationId)
                return

              if source is 'edit'

                # delete
                if changeNewValue is ''
                  console.log('delete')
                  objectTableService.removeProperty(property)

                # update existing property
                else if property? and changeNewValue isnt changeOldValue
                  console.log('edit')


                  if annotation.celltype is 'string'
                    newRow = objectTableService.updateProperty(property, changeNewValue)

                  else if annotation.celltype is 'object'
                    toObject = findObjectByName(changeNewValue)
                    newRow = objectTableService.updateProperty(property, toObject)


                # create new property
                else if not property?
                  console.log('new property')

                  table.setDataAtRowProp(changeRow, changeAnnotationId, '', 'override')
                  if annotation.celltype is 'string'
                    newRow = objectTableService.newProperty(annotation, changeNewValue)

                  else if annotation.celltype is 'object'
                    toObject = findObjectByName(changeNewValue)
                    newRow = objectTableService.newProperty(annotation, toObject)

                  else
                    return
                  table.setDataAtRowProp(newRow, changeAnnotationId, changeNewValue, 'override')

    })
  }
)










.factory('ObjectTableService', (Weaver) ->


  class ObjectTableService
    
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
      if annotation.celltype is 'object' and property.object?
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













.directive('collectionTable', (CollectionTableService, $uibModal, $timeout) ->
  {
  restrict: 'E'
  link: (scope, element) ->

    collection = scope.entity
    collectionTableService = new CollectionTableService(collection)

    editColumnModal = (filterId) ->
      filter = collectionTableService.getFilterById(filterId)

      $uibModal.open({
        animation: false
        templateUrl: 'addFilter.ng.html'
        controller: ($scope) ->

          $scope.title = 'Add column'
          $scope.columnName = filter.label
          $scope.columnType = filter.celltype
          $scope.columnPredicate = filter.predicate

          $scope.ok = ->

            # post
            if($scope.columnName? and $scope.columnName isnt '')
              fields = {label: $scope.columnName, predicate: $scope.columnPredicate, celltype: $scope.columnType}
              collectionTableService.updateFilter(filterId, fields)

              collection.$refresh = true
              $timeout((-> collection.$refresh = false), 1)

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




    containerDiv = document.createElement("div")
    element[0].appendChild(containerDiv)






    getColumns = ->
      updateColumn = (column) ->

        filterId = column.data
        filter = collectionTableService.getFilterById(filterId)


        if filter.celltype is 'string'
          column = {
            data: filterId
            type: 'text'
          }
        if filter.celltype is 'object'
          column = {
            data: filterId
            type: 'autocomplete'
            strict: false
            source: (query, process) ->

              candidates = [] #(object.name for id, object of scope.dataset.objects.$links())
              process(candidates)
          }
        column

      (updateColumn(column) for column in collectionTableService.getColumns())



    getHeaders = ->
      headers   = collectionTableService.getColumnsHeader()
      (getHTMLHeader(header) for header in headers)

    getHTMLHeader = (header) ->
      """
          <span class='table-header-title btn-stick'>#{header.name}</span>
          <button style="padding: 0; margin-top: 1px; margin-left: 3px;" class='btn btn-default btn-xs tbl-header-button' id='header_#{header.filterId}'>
            <i style='padding: 3px 5px;' class='edit-attribute fa fa-pencil'></i>
          </button>
        """


    table = new Handsontable(containerDiv, {

      data:               collectionTableService.data
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
#
#            annotation = collectionTableService.getAnnotationById(changeAnnotationId)
#            property = collectionTableService.getProperty(changeRow, changeAnnotationId)
#
#            # annotation should exist
#            if not annotation?
#              console.error('annotation not found for '+changeAnnotationId)
#              return
#
#            if source is 'edit'
#
#              # delete
#              if changeNewValue is ''
#                console.log('delete')
#                collectionTableService.removeProperty(property)
#
#                # update existing property
#              else if property? and changeNewValue isnt changeOldValue
#                console.log('edit')
#
#
#                if annotation.celltype is 'string'
#                  newRow = collectionTableService.updateProperty(property, changeNewValue)
#
#                else if annotation.celltype is 'object'
#                  toObject = findObjectByName(changeNewValue)
#                  newRow = collectionTableService.updateProperty(property, toObject)
#
#
#                # create new property
#              else if not property?
#                console.log('new property')
#
#                table.setDataAtRowProp(changeRow, changeAnnotationId, '', 'override')
#                if annotation.celltype is 'string'
#                  newRow = collectionTableService.newProperty(annotation, changeNewValue)
#
#                else if annotation.celltype is 'object'
#                  toObject = findObjectByName(changeNewValue)
#                  newRow = collectionTableService.newProperty(annotation, toObject)
#
#                else
#                  return
#                table.setDataAtRowProp(newRow, changeAnnotationId, changeNewValue, 'override')

    })
  }
)





.factory('CollectionTableService', (Weaver) ->


  class CollectionTableService
    
    constructor: (@collection) ->

      @filterMap = {}
      @objectMap = []
      @data = []

      @nextCol = 0

    
      for id, filter of @collection.filters.$links()
        @addFilter(id, filter)

      for id, object of @collection.objects.$links()
        @addobject(object)

    getColumns: ->
      ({data: id} for id of @collection.filters.$links()).sort((a,b) -> a.data.localeCompare(b.data))

    getColumnsHeader: ->
      ({name: filter.label, filterId: id} for id, filter of @collection.filters.$links()).sort((a,b) -> a.filterId.localeCompare(b.filterId))

    addFilter: (id, filter) ->

      @filterMap[id] = filter



      @nextCol++


    newFilter: (fields) ->

      filter = Weaver.add(fields, 'filter')
      @collection.filters.$push(filter)

      @addFilter(filter)


    updateFilter: (filterId, fields) ->

      filter = @getFilterById(filterId)

      if(filter?)
        for key, value of fields
          filter.$push(key, value)



    # returns row where the property is placed
    addObject: (object) ->

      @objectMap.push(object)
      row = @objectMap.length-1

      for id, property of object.properties
        console.log(id)

#        # set data
#        if annotation.celltype is 'string'
#          @data[@nextRow[annotationId]][annotationId] = property.value
#        if annotation.celltype is 'object'
#          @data[@nextRow[annotationId]][annotationId] = property.object.name




      row


    getFilterById: (id) ->
      if(@filterMap[id]?)
        return @filterMap[id]
      null



    getObject: (row) ->
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