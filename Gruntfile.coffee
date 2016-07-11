# Using exclusion patterns slows down Grunt significantly
# instead of creating a set of patterns like '**/*.js' and '!**/node_modules/**'
# this method is used to create a set of inclusive patterns for all subdirectories
# skipping node_modules, bower_components, dist, and any .dirs
# This enables users to create any directory structure they desire.
createFolderGlobs = (fileTypePatterns) ->
  if not Array.isArray(fileTypePatterns)
    fileTypePatterns = [fileTypePatterns]

  ignore = ['node_modules', 'bower_components', 'dist', 'tmp', 'server']
  fs = require('fs')
  
  map = (file) ->
    if (ignore.indexOf(file) isnt -1 or file.indexOf('.') is 0 or not fs.lstatSync(file).isDirectory())
      return null
    else
      return fileTypePatterns.map((pattern) -> return file + '/**/' + pattern)
  
  return fs.readdirSync(process.cwd()).map((file) -> map(file)).filter((patterns) -> return patterns).concat(fileTypePatterns)


module.exports = (grunt) ->

  # Load all grunt tasks
  require('load-grunt-tasks')(grunt)

  # Task configuration
  grunt.initConfig(
    connect: 
      main: 
        options: 
          livereload: 35731
          open: false
          port: 9010
          hostname: '0.0.0.0'
          base: ['.', 'src']
      
    watch: 
      main: 
        options: 
          livereload: 35731
          livereloadOnError: false
          spawn: false
        
        files: [createFolderGlobs(['*.js', '*.less', '*.html', '*.coffee']), '!_SpecRunner.html', '!.grunt']
        tasks: [] # All the tasks are run dynamically during the watch event handler
      
    clean: 
      before:
        src:['dist', 'tmp']
      after: 
        src:['tmp']
      
    
    # Automatically inject Bower components into the app
    wiredep: 
      app: 
        src: ['src/index.html']
        cwd: 'src'
        bowerJson: require('./bower.json')
        directory: 'bower_components'
        ignorePath: '../'
        exclude: ['bower_components/socket.io-client', 'bower_components/cuid', 'bower_components/x-editable']
      
    
  
    coffeelint: 
      app: ['src/**/*.coffee']
      options: 
        'arrow_spacing': 
          'level': 'error'
        
        'braces_spacing' : 
          empty_object_spaces: 0
          'level': 'error'
        
        'colon_assignment_spacing': 
          'spacing': 
            'left': 0
            'right': 1
          
          'level': 'error'
        
        'cyclomatic_complexity': 
          'level':'warn'
        
        'max_line_length': 
          'value': 120
          'level': 'error'
        
        'newlines_after_classes' : 
          'level': 'ignore'
        
        'no_debugger' : 
          'level': 'error'
        
        'no_empty_functions' : 
          'level': 'ignore'
        
        'no_empty_param_list' : 
          'level': 'error'
        
        'no_implicit_braces': 
          'level': 'ignore'
        
        'no_implicit_parens': 
          'level': 'ignore'
        
        'no_this': 
          'level': 'error'
        
        'prefer_english_operator': 
          'level': 'error'
        
      

    # Compiles CoffeeScript to JavaScript
    coffee: 
      main: 
        options: 
          sourceRoot: ''
          sourceMap: false  # Enable when coffee is also copied to tmp
    
        src: createFolderGlobs('*.coffee')
        dest: 'tmp'
        expand: true
        ext: '.js'
    
    less: 
      production: 
        files: 
          'tmp/weaver.css': 'src/app.less'
        
      
    
  
    # Validates HTML with AngularJS in mind for custom tags/attributes and file templates.
    htmlangular: 
      options: 
        tmplext: 'ng.html'
        customtags: [
          'weaver-*'
        ]
        customattrs: [
          # Weaver attributes and tags from weaver directive
          'weaver-*'
        
          # Script tags for dom-munger
          'in-production'
        
          # Right click context menu
          'context-menu'
        
          # Bootstrap Tooltip
          'tooltip'
          'tooltip-placement'
        
          # Editable
          'editable-text'
          'editable-textarea'
          'onaftersave'
          'e-form'
          ]
        reportpath: null
    
      files: 
        src: ['src/**/*.html', 'src/**/*.ng.html']
    
    ngconstant:
      options:
        name: 'config'
        dest: 'dist/config.js'
        constants:
          WEAVER_ADDRESS: process.env.WEAVER_ADDRESS or 'http://192.168.99.100:9487/'
          WEAVER_HOST: process.env.WEAVER_HOST or '192.168.99.100'
          WEAVER_PORT: process.env.WEAVER_PORT or '9487'
      default: {}

  
    ngtemplates: 
      main: 
        options: 
          module: 'weaver'
          htmlmin:'<%= htmlmin.main.options %>'
        
        src: [createFolderGlobs('*.html'), '!src/index.html', '!_SpecRunner.html']
        dest: 'tmp/templates-weaver.js'
    
  
    copy: 
      main: 
        files: [
          {cwd: 'src/img/', src: ['**'], dest: 'dist/img/', expand: true}
          {src: ['bower_components/font-awesome/fonts/**'], dest: 'dist/', filter:'isFile', expand:true}
          {src: ['bower_components/bootstrap/fonts/**'], dest: 'dist/', filter:'isFile', expand:true}
        ]
      weaver:
        files: [
          {src: ['tmp/weaver.js'], dest: 'dist/weaver.js', expand: false}
        ]
    
    
  
#    dom_munger:
#      read:
#        options:
#          read:[
#            {selector:'script[in-production!="false"]', attribute:'src', writeto:'appjs'}
#            {selector:'link[rel="stylesheet"][in-production!="false"]', attribute:'href', writeto:'appcss'}
#          ]
#
#        src: 'src/index.html'
#
#      update:
#        options:
#          remove: ['script', 'link[rel="stylesheet"]']
#          append: [
#            {selector: 'body', html:'<script src="weaver.js"></script>'}
#            {selector:'head', html:'<link rel="stylesheet" href="weaver.css">'}
#          ]
#
#        src:'src/index.html'
#        dest: 'dist/index.html'
      
    
  
    cssmin: 
      main: 
        src:['tmp/weaver.css']        # , '<%= dom_munger.data.appcss %>'
        dest:'dist/weaver.css'
      
  
    concat: 
      main: 
        src: ['<%= ngtemplates.main.dest %>', '<%= ngtemplates.runx.dest %>']      #'<%= dom_munger.data.appjs %>',
        dest: 'tmp/weaver.js'
      
    
    ngAnnotate: 
      main: 
        src:'tmp/weaver.js'
        dest: 'tmp/weaver.js'
      
    
    uglify: 
      main: 
        src: 'tmp/weaver.js'
        dest:'dist/weaver.js'
      
    
  
    htmlmin: 
      main: 
        options: 
          collapseBooleanAttributes: true
          collapseWhitespace: true
          removeAttributeQuotes: true
          removeComments: true
          removeEmptyAttributes: true
          removeScriptTypeAttributes: true
          removeStyleLinkTypeAttributes: true
        
        files: 
          'dist/index.html': 'dist/index.html'
        
      
    
  
    imagemin: 
      main:
        files: [
          expand: true, cwd:'dist/'
          src:['**/*.png', '*.jpg']
          dest: 'dist/'
        ]
  )

  grunt.registerTask('default', ['ngconstant', 'clean:after', 'coffee', 'connect', 'watch'])
  grunt.registerTask('wire', ['wiredep'])
  grunt.registerTask('build',['clean:before', 'coffeelint', 'coffee','less', 'htmlangular', 'ngtemplates','ngconstant','cssmin','concat','ngAnnotate','copy:main', 'copy:weaver', 'htmlmin','imagemin','clean:after'])   # 'dom_munger',



  grunt.event.on('watch', (action, filepath) ->

    tasksToRun = []

    if (filepath.lastIndexOf('.coffee') isnt -1 and filepath.lastIndexOf('.coffee') is filepath.length - 7)
      tasksToRun.push('coffee')
    

    if (filepath.lastIndexOf('.js') isnt -1 and filepath.lastIndexOf('.js') is filepath.length - 3) 

      # Find the appropriate unit test for the changed file
      spec = filepath
      if (filepath.lastIndexOf('-spec.js') is -1 || filepath.lastIndexOf('-spec.js') isnt filepath.length - 8)
        spec = filepath.substring(0,filepath.length - 3) + '-spec.js'
      

      # if the spec exists then lets run it
      if (grunt.file.exists(spec)) 
        files = [] #.concat(grunt.config('dom_munger.data.appjs'))
        files.push('bower_components/angular-mocks/angular-mocks.js')
        files.push(spec)
        grunt.config('karma.options.files', files)
        tasksToRun.push('karma:during_watch')
      

#    # if index.html changed, we need to reread the <script> tags so our next run of karma
#    # will have the correct environment
#    if (filepath is 'src/index.html')
#      tasksToRun.push('dom_munger:read')
    

    grunt.config('watch.main.tasks',tasksToRun)

  )
