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
    'nya.bootstrap.select'

    'config'
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

.factory('Weaver', ($window, WEAVER_ADDRESS) ->
  $window.weaver = new $window.Weaver().connect(WEAVER_ADDRESS)
  $window.weaver
)

.factory('WeaverCommons', ($window) ->
  $window.WeaverCommons
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


.controller 'AppCtrl', ($rootScope, $scope, Weaver, $window, ObjectTableService, ViewTableService, WeaverCommons, $uibModal, dataset, $timeout, WEAVER_ADDRESS ) ->

  # Init objects
  if not dataset.objects?
    dataset.objects = Weaver.collection()
    dataset.$push('objects')
  if not dataset.predicates?
    dataset.predicates = Weaver.collection()
    dataset.$push('predicates')
  if not dataset.models?
    dataset.models = Weaver.collection()
    dataset.$push('models')

  $scope.getPredicate = (predicateName) ->
    if not dataset.predicates[predicateName]?
      throw new Error('predicate not found: '+predicateName)
    console.log(dataset.predicates[predicateName])
    dataset.predicates[predicateName]

  $scope.downloadTurtle = ->
    url = WEAVER_ADDRESS + "/turtle?id=" + $scope.dataset.$id()
    $window.location.href = url
    return true

  $scope.dataset = dataset
  $scope.allObjects = []

  readAllObjects = ->
    $scope.allObjects = (object for id, object of $scope.dataset.objects.$links())

  readAllObjects()


  $scope.allPredicates = []

  readAllPredicates = ->
    $scope.allPredicates = (view for id, view of $scope.dataset.predicates.$links())

    # add default predicates
    if not dataset.predicates['rdfs:label']?
      predicate = Weaver.add({'name':'rdfs:label'}, '$PREDICATE', 'rdfs:label')
      $scope.dataset.predicates.$push(predicate)


  readAllPredicates()


  $scope.allViews = []

  readAllViews = ->
    $scope.allViews = (view for id, view of $scope.dataset.models.$links())

  readAllViews()

  # Adds a new object to the dataset
  $scope.addIndividualWithId = ->
    preferredId = prompt('Please specify the id:')
    @addIndividual(preferredId)

  # Adds a new object to the dataset
  $scope.addIndividual = (preferredId) ->

    # Create object and add to dataset
    if(preferredId?)
      object = Weaver.add({name: 'Unnamed Individual', source: 'workbench'}, '$INDIVIDUAL', preferredId)

    else
      object = Weaver.add({name: 'Unnamed Individual', source: 'workbench'}, '$INDIVIDUAL')

    # Create object and add to dataset
    $scope.dataset.objects.$push(object)

    # Create first annotation
    object.annotations = Weaver.collection()
    object.$push('annotations')


    # Create first property
    object.properties = Weaver.collection()
    object.$push('properties')


    # Open by default
    $scope.openTabs.push(object)
    $scope.activeTab = object
    readAllObjects()
    readAllPredicates()
    readAllViews()

  # Adds a new object to the dataset
  $scope.addView = ->

    # Create object and add to dataset
    view = Weaver.add({name: 'Unnamed View'}, '$VIEW')
    $scope.dataset.models.$push(view)


    # Create filters view
    view.filters = Weaver.collection()
    view.$push('filters')

    labelPredicate = $scope.getPredicate('rdfs:label').$id()
    filter = Weaver.add({label: 'has name', predicate: labelPredicate, celltype: 'string'}, '$FILTER')

    # Create condition list
    filter.conditions = Weaver.collection()
    filter.$push('conditions')
    condition = Weaver.add({operation:'any-value', value:'', conditiontype:'string'}, '$CONDITION')
    filter.conditions.$push(condition)

    view.filters.$push(filter)

    # Create objects set
    view.objects = Weaver.collection()
    view.$push('objects')

    # Open by default
    $scope.openTabs.push(view)
    $scope.activeTab = view
    readAllObjects()
    readAllPredicates()
    readAllViews()

  # Adds a new object to the dataset
  $scope.addPredicate = ->

    predicateName = prompt('Please specify the predicate:')

#    payload = new WeaverCommons.create.Predicate({'id':predicateName,'name':predicateName})



    # Create object and add to dataset
    predicate = Weaver.add({'name':predicateName}, '$PREDICATE', predicateName)
    $scope.dataset.predicates.$push(predicate)

    # Open by default
    $scope.openTabs.push(predicate)
    $scope.activeTab = predicate
    readAllObjects()
    readAllPredicates()
    readAllViews()

  $scope.exportQuads = (entity) =>
    selectorEntity = entity.$.id
    if selectorEntity.indexOf(':') < 0
      selectorEntity = 'ins:' + selectorEntity

    Weaver.channel.nativeQuery(
      {
        query: 'select * where { graph ?g { ?s ?p ?o} graph ?g { '+selectorEntity+' ?p_ ?o_ } }'
        selects: ['s', 'p', 'o', 'g']
      }
    ).then(
      (result) =>
        $scope.quadScreen = result
        $scope.$apply() if !$scope.$$phase
    )

  $scope.quadScreen = [[]]
    
  $scope.addColumn = (entity) ->

    if entity.$type() is '$INDIVIDUAL'

      if not entity.annotations?
        entity.annotations = Weaver.collection()
        entity.$push('annotations')

      labelPredicate = $scope.getPredicate('rdfs:label').$id()
      annotation = Weaver.add({celltype: 'string', predicate: labelPredicate}, '$ANNOTATION')
      entity.annotations.$push(annotation)
      entity.$refresh = true
      $timeout((-> entity.$refresh = false), 1)

    else if entity.$type() is '$VIEW'

      labelPredicate = $scope.getPredicate('rdfs:label').$id()
      filter = Weaver.add({label: 'has name', predicate: labelPredicate, celltype: 'string'}, '$FILTER')

      # Create condition list
      filter.conditions = Weaver.collection()
      filter.$push('conditions')
      condition = Weaver.add({operation:'any-value', value:'', conditiontype:'string'}, '$CONDITION')
      filter.conditions.$push(condition)

      entity.filters.$push(filter)
      entity.$refresh = true
      $timeout((-> entity.$refresh = false), 1)

    else
      console.error('adding column to unsupported entity type: '+entity.$type())

  $scope.deleteObject = (object) ->
    $scope.closeTab(object)
    location = $scope.allObjects.indexOf(object)
    $scope.allObjects.splice(location, 1)
    $scope.dataset.objects.$remove(object)
    object.$destroy()

  $scope.deletePredicate = (predicate) ->
    $scope.closeTab(predicate)
    location = $scope.allPredicates.indexOf(predicate)
    $scope.allPredicates.splice(location, 1)
    $scope.dataset.predicates.$remove(predicate)
    predicate.$destroy()

  $scope.deleteView = (view) ->
    $scope.closeTab(view)
    location = $scope.allViews.indexOf(view)
    $scope.allViews.splice(location, 1)
    $scope.dataset.models.$remove(view)
    view.$destroy()

    


  $scope.activeTree = 'individual'
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

  $scope.predicateTreeOptions = {
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

  $scope.viewTreeOptions = {
    injectClasses: {
      ul: "c1"
      li: "c2"
      liSelected: "c7"
      iExpanded: "c3"
      iCollapsed: "c4"
      iLeaf: "c5"
      label: "c6"
      labelSelected: "c8"
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

  $scope.buttonClick = (event, node) ->

    $scope.lastClicked = node
    
    $scope.openTabs.push(node) if $scope.openTabs.indexOf(node) is -1
    $scope.activeTab = node
    
    event.stopPropagation()











.directive('predicateTable', ($uibModal, $timeout) ->
  {
    restrict: 'E'
    link: (scope, element) ->

      predicate = scope.entity
      dataset = scope.dataset

      tableElement = element[0]

      containerDiv = document.createElement('div')
      containerDiv.innerHTML = '<br/><br/><br/><br/>' + predicate.preferredName + '<br/>' + predicate.reversedName
      element[0].appendChild(containerDiv)
  }
)













.directive('objectTable', (ObjectTableService, $uibModal, $timeout) ->
  {
    restrict: 'E'
    link: (scope, element) ->

      object = scope.entity
      dataset = scope.dataset
      objectTableService = new ObjectTableService(object)

      editColumnModal = (annotationId) ->
        annotation = objectTableService.getAnnotationById(annotationId)

        if annotation?

          $uibModal.open({
            animation: false
            templateUrl: 'addAnnotation.ng.html'
            controller: ($scope) ->

              $scope.title = 'Add column'
              $scope.columnName = annotation.predicate
              $scope.columnType = annotation.celltype
              $scope.predicates = dataset.predicates


              $scope.delete = ->

                # check if this is annotation has any properties
                if objectTableService.getPropertiesForAnnotationId(annotationId).length > 0
                  window.alert('cannot be deleted, there are still properties')
                else

                  object.annotations.$remove(annotation)
                  # todo actually remove the annotation object

                  # refresh the table
                  object.$refresh = true
                  $timeout((-> object.$refresh = false), 1)


                  $scope.$close()

              $scope.ok = ->

                # post
                if($scope.columnName? and $scope.columnName isnt '')

                  labelPredicate = $scope.selectedPredicate.id
                  fields = {
                    name: labelPredicate
                    predicate: labelPredicate
                    celltype: $scope.columnType
                  }

                  objectTableService.updateAnnotation(annotationId, fields)

                  object.$refresh = true
                  $timeout((-> object.$refresh = false), 1)

                $scope.$close()

              $scope.cancel = ->
                # clean
                $scope.$close()

            size: 'sm'
          })

        # probably unannotated
        else
          predicate = objectTableService.getUnannotationById(annotationId)
          console.log('found unannotated predicate '+predicate)


      tableElement = element[0]

      tableElement.addEventListener('mousedown', (event) ->


        if event.target.classList? and event.target.classList[0] is 'edit-attribute'
          event.stopPropagation()
          headerDivId = $(event.target).parent()[0].id
          annotationId = headerDivId.substr(7)
          editColumnModal(annotationId)

      , true)

      tableElement.addEventListener('mousedown', (event) ->

        if event.metaKey
          event.stopPropagation()

          if objectTableService.selectedCol? and objectTableService.selectedRow?

            annotationId = objectTableService.getColIdByCol(objectTableService.selectedCol)
            property = objectTableService.getProperty(objectTableService.selectedRow, annotationId)

            if property.$type() is '$INDIVIDUAL_PROPERTY'

              scope.buttonClick(event, property.object)
              scope.$apply()



      , true)





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

          # default
          column = {
            data: annotationId
            type: 'text'
          }

          if annotation?

            if annotation.celltype is 'string'
              column = {
                data: annotationId
                type: 'text'
              }
            if annotation.celltype is 'individual'
              column = {
                data: annotationId
                type: 'autocomplete'
                strict: false
                source: (query, process) ->

                  candidates = (object.name for id, object of scope.dataset.objects.$links())
                  process(candidates)
              }


          # probably unannotation
          else
            column = {
              data: annotationId
              type: 'text' # todo distingish
              editor: false
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

        afterSelection: (r, c, r2, c2) ->

          objectTableService.setSelectedCell(r, c)


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

                  if property.$type() is '$VALUE_PROPERTY'
                    newRow = objectTableService.updateProperty(property, changeNewValue)

                  else if property.$type() is '$INDIVIDUAL_PROPERTY'
                    toObject = findObjectByName(changeNewValue)
                    newRow = objectTableService.updateProperty(property, toObject)


                # create new property
                else if annotation? and not property?
                  console.log('new property')

                  table.setDataAtRowProp(changeRow, changeAnnotationId, '', 'override')

                  if annotation.celltype is 'string'
                    newRow = objectTableService.newProperty(annotation, changeNewValue)

                  else if annotation.celltype is 'individual'
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
      @unannotationsMap = {}      # predicate -> cuid
      @propertyMap = {}
      @data = []

      @nextCol = 0
      @nextRow = {}

      if @object.annotations?
        for id, annotation of @object.annotations.$links()
          @addAnnotation(id, annotation)

      for id, property of @object.properties.$links()
        annotation = property.annotation
        if annotation?
          @addProperty(annotation, property)
        else
          @addUnannotatedProperty(property)
          
    getPropertiesForAnnotationId: (id) ->
      result = []
      for rowId, row of @propertyMap
        for annotationId, property of row when annotationId is id
          result.push(property) 
      return result
      

    getColumns: ->
      annotations = []
      if @object.annotations?
        annotations.push({data: id}) for id of @object.annotations.$links()
      annotations.push({data: id}) for predicate, id of @unannotationsMap
      annotations.sort((a,b) -> a.data.localeCompare(b.data))

    getColumnsHeader: ->
      headers = []
      if @object.annotations?
        headers.push({name:annotation.predicate, annotationId:id, annotated: true}) for id, annotation of @object.annotations.$links()
      headers.push({name:predicate, annotationId:id, annotated: false}) for predicate, id of @unannotationsMap
      headers.sort((a,b) -> a.annotationId.localeCompare(b.annotationId))

    addAnnotation: (id, annotation) ->

      @annotationMap[id] = annotation

      if not @nextRow[id]?
        @nextRow[id] = 0

      @nextCol++


    updateAnnotation: (annotationId, fields) ->

      annotation = @getAnnotationById(annotationId)
      if(annotation?)
        for key, value of fields
          annotation.$push(key, value)
      else
        console.error('annotation '+annotationId+' not found for update')


    setSelectedCell: (row, col) ->
      @selectedRow = row
      @selectedCol = col

    # returns row where the property is placed
    addProperty: (annotation, property) ->

      annotationId = annotation.$id()

      if not @data[@nextRow[annotationId]]?
        @data.push({})

      # set data
      if property.$type() is '$VALUE_PROPERTY'
        @data[@nextRow[annotationId]][annotationId] = property.object
      if property.$type() is '$INDIVIDUAL_PROPERTY' and property.object?
        @data[@nextRow[annotationId]][annotationId] = property.object.name

      # set property
      if(not @propertyMap[@nextRow[annotationId]]?)
        @propertyMap[@nextRow[annotationId]] = {}
      @propertyMap[@nextRow[annotationId]][annotationId] = property

      @nextRow[annotationId] += 1
      @nextRow[annotationId]-1

    # returns row where the property is placed
    addUnannotatedProperty: (property) ->

      predicateName = property.predicate

      if not @unannotationsMap[predicateName]?
        newid = cuid()
        @unannotationsMap[predicateName] = newid

        if not @nextRow[newid]?
          @nextRow[newid] = 0

        @nextCol++

      annotationId = @unannotationsMap[predicateName]

      if not @data[@nextRow[annotationId]]?
        @data.push({})

      # set data
      if property.$type() is '$VALUE_PROPERTY'
        @data[@nextRow[annotationId]][annotationId] = property.object
      if property.$type() is '$INDIVIDUAL_PROPERTY' and property.object?
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

        property = Weaver.add({subject: @object, predicate: annotation.predicate, object: value}, '$VALUE_PROPERTY')
        property.$push('annotation', annotation)

      if annotation.celltype is 'individual'

        property = Weaver.add({subject: @object, predicate: annotation.predicate, object: value}, '$INDIVIDUAL_PROPERTY')
        property.$push('annotation', annotation)

      if not property?
        return

      if not @object.properties?
        @object.properties = Weaver.collection()
        @object.$push('properties')

      @object.properties.$push(property)

      @addProperty(annotation, property)


    updateProperty: (property, value) ->

      if property.$type() is '$VALUE_PROPERTY'
        property.$push('object', value)
      if property.$type() is '$INDIVIDUAL_PROPERTY'
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

    # returns predicate string
    getUnannotationById: (id) ->

      for predicate, cuid of @unannotationsMap
        if cuid is id
          return predicate
      'unannotated'

    getColIdByCol: (col) ->
      @getColumns()[col].data



    getProperty: (row, id) ->
      if(@propertyMap[row]?)
        if(@propertyMap[row][id]?)
          return @propertyMap[row][id]
      null


)













.directive('viewTable', (ViewTableService, Weaver, $uibModal, $timeout) ->
  {
  restrict: 'E'
  link: (scope, element) ->

    # directive attributes
    viewEntity = scope.entity
    dataset = scope.dataset

    Weaver.getView(viewEntity.$id())
    .then((view) ->
      view.populate()
    ).then((population) =>
      viewTableService = new ViewTableService(viewEntity, population, scope)

      editColumnModal = (filterId) ->
        filter = viewTableService.getFilterById(filterId)

        $uibModal.open({
          animation: false
          templateUrl: 'addFilter.ng.html'
          controller: ($scope) ->


            operationsString = {
              'any-value': 'none'
              'exact-value': 'string'
              'regex': 'string'
              '-1': '-'
              'min-card': 'string'
              'max-card': 'string'
            }
            operationsObject = {
              'any-individual':'none'
              'this-individual':'individual'
              'not-this-individual':'individual'
              '-1':'-'
              'any-from-model':'model'
              '-2':'-'
              'min-card':'string'
              'max-card':'string'
            }

            $scope.title = 'Add filter'

            $scope.predicates = dataset.predicates

            $scope.filterName = filter.label
            if not filter.predicateEntity?
              console.error('no predicateEntity found on this filter, should look for one with this id '+filter.predicate)
            $scope.filterPredicate = filter.predicateEntity
            $scope.filterType = filter.celltype

            $scope.filterTypeString = (filter.celltype is 'string')
            $scope.filterTypeIndividual = (filter.celltype is 'individual')


            $scope.operations = operationsString # default
            if $scope.filterTypeIndividual
              $scope.operations = operationsObject

            $scope.conditions = filter.conditions
            $scope.objects = dataset.objects.$links()
            $scope.models = dataset.models.$links()







            $scope.switchToString = ->
              if $scope.filterTypeIndividual
                $scope.filterTypeString = true
                $scope.filterTypeIndividual = false
                $scope.filterType = 'string'
                $scope.operations = operationsString
                $scope.removeCondition(condition) for key, condition of $scope.conditions.$links()
                if((key for key of $scope.conditions.$links()).length < 1)
                  $scope.addCondition()



            $scope.switchToIndividual = ->
              if $scope.filterTypeString
                $scope.filterTypeString = false
                $scope.filterTypeIndividual = true
                $scope.filterType = 'individual'
                $scope.operations = operationsObject
                $scope.removeCondition(condition) for key, condition of $scope.conditions.$links()
                if((key for key of $scope.conditions.$links()).length < 1)
                  $scope.addCondition()









            $scope.addCondition = ->
              if $scope.filterTypeString
                condition = Weaver.add({operation: 'any-value', value:'', conditiontype:'string'}, '$CONDITION')
              else if $scope.filterTypeIndividual
                condition = Weaver.add({operation: 'any-individual', value:'', conditiontype:'individual'}, '$CONDITION')

              $scope.conditions.$push(condition)


            $scope.removeCondition = (condition) ->
              $scope.conditions.$remove(condition.$id())

              if((key for key of $scope.conditions.$links()).length < 1)
                $scope.addCondition()
                
                

            $scope.delete = ->

              viewEntity.filters.$remove(filter)
              # todo actually remove the filter object and its conditions from redis

              # refresh the table
              viewEntity.$refresh = true
              $timeout((-> viewEntity.$refresh = false), 1)
              
              $scope.$close()


            $scope.ok = ->

              # post
              if($scope.filterName? and $scope.filterName isnt '')

                filter.$push('label', $scope.filterName)
                filter.$push('predicate', $scope.filterPredicate.id)
                filter.$push('predicateEntity', $scope.filterPredicate)
                filter.$push('celltype', $scope.filterType)

                for key, condition of $scope.conditions.$links()

                  condition.$push('operation')

                  # determine operation type
                  operationType = 'none'
                  if condition.conditiontype is 'string'
                    operationType = operationsString[condition.operation]
                  if condition.conditiontype is 'individual'
                    operationType = operationsObject[condition.operation]

                  # act on the operation type
                  if operationType is 'none'
                    # do nothing

                  else if operationType is 'string'
                    condition.$push('value')

                  else if operationType is 'individual'
                    condition.value =  condition.individualEntity.$id()
                    condition.$push('individualEntity')
                    condition.$push('value')

                  else if operationType is 'model'
                    condition.value =  condition.modelEntity.$id()
                    condition.$push('modelEntity')
                    condition.$push('value')

                viewEntity.$refresh = true
                $timeout((-> viewEntity.$refresh = false), 1)

              $scope.$close()

            $scope.cancel = ->

              # clean
              $scope.$close()

          size: 'md'
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
          filter = viewTableService.getFilterById(filterId)

          # default
          column = {
            data: filterId
            type: 'text'
            editor: false
          }

          if filter?

            if filter.celltype is 'string'
              column = {
                data: filterId
                type: 'text'
                editor: false
              }
            if filter.celltype is 'individual'
              column = {
                data: filterId
                type: 'text'
                editor: false
              }
          column

        (updateColumn(column) for column in viewTableService.getColumns())



      getHeaders = ->
        headers   = viewTableService.getColumnsHeader()
        (getHTMLHeader(header) for header in headers)

      getHTMLHeader = (header) ->
        """
          <span class='table-header-title btn-stick'>#{header.name}</span>
          <button style="padding: 0; margin-top: 1px; margin-left: 3px;" class='btn btn-default btn-xs tbl-header-button' id='header_#{header.filterId}'>
            <i style='padding: 3px 5px;' class='edit-attribute fa fa-pencil'></i>
          </button>
        """


      table = new Handsontable(containerDiv, {

        data:               viewTableService.data
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

      })
    )

  }
)





.factory('ViewTableService', (Weaver) ->


  class ViewTableService
    
    constructor: (@view, @population, @scope) ->

      @filterMap = {}
      @objectMap = []
      @data = []

      @nextCol = 0

      for id, filter of @view.filters.$links()
        @addFilter(id, filter)

      for id, object of @population
        @addObject(object)

    getColumns: ->
      ({data: id} for id of @view.filters.$links()).sort((a,b) -> a.data.localeCompare(b.data))

    getColumnsHeader: ->
      ({name: filter.label, filterId: id} for id, filter of @view.filters.$links()).sort((a,b) -> a.filterId.localeCompare(b.filterId))

    addFilter: (id, filter) ->

      @filterMap[id] = filter
      @nextCol++


    # returns row where the property is placed
    addObject: (object) ->

      if not object.$type() is '$INDIVIDUAL'
        return

      if not object.properties?
        console.error('individual has no properties:')
        console.error(object)
        return

      @objectMap.push(object)
      row = @objectMap.length-1

      for id, property of object.properties.$links()
        @addProperty(property, row)




      row

    # returns row where the property is placed
    addProperty: (property, row) ->

      predicate = property.predicate
      for filterId, filter of @filterMap
        if filter.predicate is predicate

          if not @data[row]?
            @data.push({})

          # set data
          if property.$type() is '$VALUE_PROPERTY'
            @data[row][filterId] = property.object
          if property.$type() is '$INDIVIDUAL_PROPERTY' and property.object?
            @data[row][filterId] = property.object.name 



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
