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
    'ui.bootstrap'
    'treeControl'
  ]


# Configuration
.config(($urlRouterProvider, $stateProvider) ->

  # Default route all to /
  $urlRouterProvider.otherwise('/')

  # Weaver app template
  $stateProvider

  .state 'main',
    template: ''

  .state 'app',
    url: '/app',
    templateUrl: 'src/app.ng.html'
    controller: 'AppCtrl'
)

.factory('Weaver', ($window) ->
  new $window.Weaver('http://localhost:9487')
)

.run(($state, Weaver) ->
  
  # Head to the main state
  $state.go('main')
)

.factory('TableService', (Weaver) ->


  class TableService


    annotationMap: {}
    propertyMap: {}
    data: []

    nextCol: 0
    nextRow: {}


    constructor: (@object) ->

      for id, annotation of @object.annotations.$links()
        @addAnnotation(id, annotation)

    getData: () ->

      console.log(@data)
      @data

    getColumns: ->
      cols = []
      for id, annotation of @object.annotations.$links()
        cols.push({data: id})

      return cols


    getColumnsHeader: ->
      cols = []
      for id, annotation of @object.annotations.$links()
        cols.push(annotation.label)

      return cols

    addAnnotation: (id, annotation) ->

      # set annotationMap
      @annotationMap[id] = annotation


      if not @nextRow[id]?
        @nextRow[id] = 0

      for propertyId, property of annotation.properties.$links()

        if property.value?
          @addProperty(id, property)

      @nextCol += 1



    newAnnotation: (annotationName) ->


      annotation = Weaver.add({label: annotationName}, 'annotation')
      annotation.properties = Weaver.add({},'_COL')
      annotation.$push('properties')
      @object.annotations.$push(annotation)

      @addAnnotation(annotation.$id(), annotation)

    addProperty: (annotationId, property) ->


      # create new row if needed
#      if @data.indexOf(@nextRow[annotationId]) is -1
#        @data.push({})

      while not @data[@nextRow[annotationId]]?
        @data.push({})

      # set data
      @data[@nextRow[annotationId]][annotationId] = property.value

      # set property
      if(not @propertyMap[@nextRow[annotationId]]?)
        @propertyMap[@nextRow[annotationId]] = {}
      @propertyMap[@nextRow[annotationId]][annotationId] = property


      @nextRow[annotationId] += 1


    newProperty: (annotation, value) ->

      property = Weaver.add({value: value}, 'property')
      annotation.properties.$push(property)

      @addProperty(annotation.$id(), property)

    updateProperty: (property, value) ->
      property.$push('value', value)


    removeProperty: (annotation, property) ->
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


.controller 'AppCtrl', ($rootScope, $scope, Weaver, TableService, $uibModal) ->

  $scope.activeTree = 'data'
  $scope.selectView = (viewName) ->

    $scope.activeTree = viewName



  createSubTree = (level, width, prefix) ->

    if (level > 0)
      res = []
      for  i in [1 .. width]
        res.push({
          "label": "Node " + prefix + i,
          "id": "id" + prefix + i,
          "i": i,
          "children": createSubTree(level - 1, width, prefix + i + ".")
        })

      return res
    else
      return []



  $scope.datatree = createSubTree(3, 4, "")
  $scope.collectiontree = createSubTree(1, 4, "")


  $scope.lastClicked = null;

  $scope.buttonClick = ($event, node) ->
    $scope.lastClicked = node
    $scope.message = node.label
    $event.stopPropagation()

  $scope.showSelected = (sel) ->
    $scope.message = sel.label
    $scope.selectedNode = sel


  $scope.openAddColumnModal = ->
    $uibModal.open({
      animation: false
      templateUrl: 'addColumn.ng.html'
      controller: ($scope) ->
        $scope.title = 'Add column'
        $scope.columnName = 'nameless'

        $scope.ok = ->

          # post
          annotationName = $scope.columnName
          if(annotationName? and annotationName isnt '')

            tableService.newAnnotation(annotationName)
            updateTableHeaders()
            updateTableData()

          $scope.$close();


        $scope.cancel = ->
          # clean
          $scope.$close();


      size: 'sm'
    })


  tableService = null
  Weaver.get('ciljobavr00003j6jteznev4e', {eagerness: -1}).then((object) ->
    console.log(object)
    tableService = new TableService(object)
    start()
  )















  table = null
  start = ->
    table = new Handsontable($('#tables-container')[0],

      {

        data:               tableService.getData()
        columns:            tableService.getColumns()
        colHeaders:         tableService.getColumnsHeader()
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
                  tableService.newProperty(annotation, changeNewValue)

      })


  updateTableHeaders = () ->
    table.updateSettings({
      columns:            tableService.getColumns()
      colHeaders:         tableService.getColumnsHeader()
    })

  updateTableData = () ->
    table.updateSettings({
      data:               tableService.getData()
    })




