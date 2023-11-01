// requires anchorectl
// requires anchore enterprise 
// requires jq
//
pipeline {
  environment {
    // set some variables
    //
    // we don't need registry if using docker hub
    // but if you're using a different registry, set this 
    REGISTRY = 'docker.io'
    //
    // you will need a credential with your docker hub user/pass
    // (or whatever registry you're using) and a credential with
    // user/pass for your anchore instance:
    // ...
    // first let's set the docker hub credential and extract user/pass
    // we'll use the USR part for figuring out where are repository is
    HUB_CREDENTIAL = "docker-hub"
    // use credentials to set DOCKER_HUB_USR and DOCKER_HUB_PSW
    DOCKER_HUB = credentials("${HUB_CREDENTIAL}")
    //
    // assuming you want to use docker hub, this shouldn't need
    // any changes, but if you're using another registry, you
    // may need to tweak REPOSITORY 
    REPOSITORY = "${DOCKER_HUB_USR}/anchorectl-test"
    TAG = "build-${BUILD_NUMBER}"
    //
    IMAGE = "${REGISTRY}/${REPOSITORY}:${TAG}"
    //
  } // end environment

  agent any
  
  stages {
    stage('Checkout SCM') {
      steps {
        checkout scm
      } // end steps
    } // end stage "checkout scm"    
    
    stage('Build Image') {
      steps {
        script {
          // login to docker hub (or whatever registry)
          // build image and push it to registry
          //
          // You can replace this with whatever docker build/push plugin you prefer, 
          // it doesn't really matter, just get it built here. 
          //
          // alternatively, if you want to scan the image locally without pushing 
          // it somewhere first, we can do that (see the next stage for details)
          //
          sh """
            echo "${DOCKER_HUB_PSW}" | docker login ${REGISTRY} -u ${DOCKER_HUB_USR} --password-stdin
            docker build -t ${IMAGE} --pull -f ./Dockerfile .
            docker push ${IMAGE}
          """
          // 
          // e.g. I don't like using the docker plugin but if you want to use it, 
          // here ya go:
          // DOCKER_IMAGE = docker.build REPOSITORY + ":" + TAG
          // docker.withRegistry( '', HUB_CREDENTIAL ) { 
          //  DOCKER_IMAGE.push() 
          // }
        } // end script
      } // end steps
    } // end stage "Build Image"
    
    stage('Analyze Image w/ anchorectl') {
      environment {
        ANCHORECTL_URL = credentials("Anchorectl_Url")
        ANCHORECTL_USERNAME = credentials("Anchorectl_Username")
        ANCHORECTL_PASSWORD = credentials("Anchorectl_Password")
        // change ANCHORECTL_FAIL_BASED_ON_RESULTS to "true" if you want to break on policy violations
        ANCHORECTL_FAIL_BASED_ON_RESULTS = "false"
      }
      steps {
        script {
          sh """
            ### install anchorectl 
            curl -sSfL  https://anchorectl-releases.anchore.io/anchorectl/install.sh  | sh -s -- -b $HOME/.local/bin v4.9.0
            export PATH="$HOME/.local/bin/:$PATH"          
            #
            ### actually add the image to the queue to be scanned
            
            anchorectl image add --wait --dockerfile ./Dockerfile --from docker ${IMAGE}

            ### this is a "distributed" scan, meaning anchorectl grabs the image from the local docker daemon,
            ### generates the SBOM locally, then pushes that SBOM to the Anchore Enterprise API.  See below for
            ### other SBOM generation options.
            #
            ### explanation of command-line flags/options:
            #
            ### --wait tells anchorectl to block until the scan is complete (this isn't always necessary but if you  
            ### want to pull the vulnerability list and/or policy report, you probably want to wait
            #
            ### --no-auto-subscribe tells the policy engine to just pull the image and scan it once. If you  
            ### don't pass this option, anchore enterprise will continually poll the tag to see if any new
            ### version has been pushed and if it detects a new image, it automatically pulls it and scans it.
            #
            ### --force tells Anchore Enterprise to build a new SBOM even if one already exists in the catalog
            #
            ### --dockerfile is optional but if you want to test Dockerfile instructions this is recommended
            #
            #
            #
            ### Alternative SBOM creation options:
            #
            ### 1) to use "Centralized" scanning (i.e. the Anchore Enterprise product pulls the target image to the
            ### backend Analyzer service and creates the SBOM there):
            #
            # anchorectl image add --wait --no-auto-subscribe --force --dockerfile ./Dockerfile ${IMAGE}
            #
            ### Note that this method may need registry credentials stored in Anchore Enterprise.
            #
            ### 2) You can have anchorectl pull the image from registry, generate the sbom locally, and push the 
            ### sbom to the Anchore Enterprise API (--from registry).  This is still a distributed scan but the 
            ### image is pulled from registry rather than from docker daemon.
            #
            # anchorectl image add --wait --dockerfile ./Dockerfile --from registry ${IMAGE} 
            #
            ### note in this case you don't need to push the image first
            ###
            ###
            ### uncomment to pull vulnerability list (optional)
            # anchorectl image vulnerabilities ${IMAGE}
            ###
            ### check policy evaluation
            # anchorectl image check --detail ${IMAGE}
            ### 
            ### if you want to break the pipeline on a policy violation, add "--fail-based-on-results"
            ### or change the ANCHORECTL_FAIL_BASE_ON_RESULTS variable above to "true"
          """
        } // end script 
      } // end steps
    } // end stage "analyze with anchorectl"

    stage('Pull SBOM') {
      environment {
        ANCHORECTL_URL = credentials("Anchorectl_Url")
        ANCHORECTL_USERNAME = credentials("Anchorectl_Username")
        ANCHORECTL_PASSWORD = credentials("Anchorectl_Password")
        // change ANCHORECTL_FAIL_BASED_ON_RESULTS to "true" if you want to break on policy violations
        ANCHORECTL_FAIL_BASED_ON_RESULTS = "false"
      }
      // Grab SBOM from Anchore API and format it as needed
      steps {
        sh """
          ### need to reset PATH since Jenkins forgets between stages
          export PATH="$HOME/.local/bin/:$PATH"          
          anchorectl image sbom -o syft-json ${IMAGE} | jq -r '.artifacts[] | [ .type, .name, .metadata.vendor, .metadata.version, .cpes[0]  ] | @csv' > components.csv
        """
      } // end steps
    } // end stage "clean up"
    
    // optional stage, this just deletes the image locally so I don't end up with 300 old images
    //
    stage('Clean Up') {
      // delete the images locally
      steps {
        sh 'docker rmi ${IMAGE} || failure=1' 
        //
        // the "|| failure=1" at the end of this line just catches problems with the :prod
        // tag not existing if we didn't uncomment the optional "re-tag as prod" stage
        //
      } // end steps
    } // end stage "clean up"
    
  } // end stages

  post {
    always {
      // archive the formatted csv sbom:
      archiveArtifacts artifacts: '*csv'
    } // end always
  } //end post
  
} // end pipeline
