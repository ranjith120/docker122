pipeline {
  environment {
    // DEV Env
    AZURE_VM01 = "${env.AZURE_CITI_VM01}"
    AZURE_VM02 = "${env.AZURE_CITI_VM02}"

    // QA Env
    AZURE_QA01 = "${env.AZURE_CITI_QA01}"
    AZURE_QA02 = "${env.AZURE_CITI_QA02}"

    // Global Env
    REMOTE_SERVER_UPLOAD_FOLDER = "/home/adminuser/downloads"
    REMOTE_SERVER_UPLOAD_USERNAME = "${env.jenkins_azure_ssh_username}"
    REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER = "/opt/apache-tomcat-9.0.6/webapps"

    // Deploy to ....
    DEPLOY_TO_ENVIRONMENT = "${ENVIRONMENT}"

    // Step. For separate jenkins jobs
    JENKINS_STEP = "${STEP}"

    // OPENSHIFT variables
    OPENSHIFT_PROJECT_ID = "73a28cdef0e44691af12"
    OPENSHIFT_PROJECT_ADDRESS = "https://openshift.${OPENSHIFT_PROJECT_ID}.eastus2.azmosa.io"
    OPENSHIFT_DOCKER_ADDRESS = "docker-registry.apps.${OPENSHIFT_PROJECT_ID}.eastus2.azmosa.io"
    OPENSHIFT_NAME_SPACE = "citi-iso-ch"

    openshiftAuthToken = null

  }

  stages{
    stage('Starting') {
      steps {

        echo "Environment variables available on start of this build:"
        sh 'printenv | sort'
        script {
          /* Check the GIT_BRANCH to compute the target environment */
          if (env.GIT_BRANCH == 'origin/main' &&  DEPLOY_TO_ENVIRONMENT=='DEV') {
            target = 'dev'
          } else if (env.GIT_BRANCH == 'origin/main' &&  DEPLOY_TO_ENVIRONMENT=='QA') {
            target = 'qa'
          } else if (env.GIT_BRANCH == 'origin/main' &&  DEPLOY_TO_ENVIRONMENT=='OPENSHIFT') {
            target = 'pre'
          }
          /* Create the real version with Jenkins BUILD_NUMBER */
          version = env.BUILD_NUMBER

          /* Create remote server upload path */
          remote_server_folder = env.REMOTE_SERVER_UPLOAD_FOLDER + "/volpay-" + version


          checkoutCode ()
          compileAndBuild ()
          
          if ( JENKINS_STEP == 'TEST' ){
            unitTest ()
          }

          if ( JENKINS_STEP == 'DEPLOY' && (target == 'dev') ){
            copyRemoteWarFiles ("DEV", AZURE_VM01, AZURE_VM02)
          }

          if ( JENKINS_STEP == 'DEPLOY' && (target == 'qa') ){
            copyRemoteWarFiles ("QA", AZURE_QA01, AZURE_QA02)
          }

          if ( JENKINS_STEP == 'DEPLOY' && (target == 'pre' || target == 'pro') ){
            getJenkinsSACredentials()

            createImage ('instruction', OPENSHIFT_DOCKER_ADDRESS, version)
            deployImage ('instruction', OPENSHIFT_DOCKER_ADDRESS, version)

            createImage ('rest', OPENSHIFT_DOCKER_ADDRESS, version)
            deployImage ('rest', OPENSHIFT_DOCKER_ADDRESS, version)

//            createImage ('script', OPENSHIFT_DOCKER_ADDRESS, version)
//            deployImage ('script', OPENSHIFT_DOCKER_ADDRESS, version)

            createImage ('sync', OPENSHIFT_DOCKER_ADDRESS, version)
            deployImage ('sync', OPENSHIFT_DOCKER_ADDRESS, version)

            createImage ('transaction', OPENSHIFT_DOCKER_ADDRESS, version)
            deployImage ('transaction', OPENSHIFT_DOCKER_ADDRESS, version)

            createImage ('volpayui', OPENSHIFT_DOCKER_ADDRESS, version)
            deployImage ('volpayui', OPENSHIFT_DOCKER_ADDRESS, version)

          }
        }
      }
    }

  }

}

def createImage (volpayServiceName, registryName, version){
  stage ('Creating ' + volpayServiceName + ' Image'){
    
    def imagenameUI = registryName + '/${OPENSHIFT_NAME_SPACE}/citi-iso-' + volpayServiceName +'-service:' + version
    
    sh "cp /root/license/volante-runtime-license-enterprise.jar ./webapps/"+volpayServiceName+"/deploy/volante-runtime-license-enterprise.jar"

    docker.build(imagenameUI, "-f webapps/"+volpayServiceName+"/Dockerfile .")

  }
}

def deployImage(volpayServiceName, registryName, version){
  stage ('Deploy ' + volpayServiceName+' Image'){
    
    def imagenameUI = registryName + '/${OPENSHIFT_NAME_SPACE}/citi-iso-' + volpayServiceName +'-service:' + version
    
    sh "oc login ${OPENSHIFT_PROJECT_ADDRESS} --token=${openshiftAuthToken}"
    sh "oc whoami"
    sh "docker login ${OPENSHIFT_DOCKER_ADDRESS} -u \$(oc whoami) -p \$(oc whoami -t)"
    sh "oc project ${OPENSHIFT_NAME_SPACE}"
    sh "docker push " + imagenameUI
    sh "sed -e 's#{REGISTRY_NAME_SPACE}#${OPENSHIFT_NAME_SPACE}#g;s#{VOLPAY_SERVICE_NAME}#${volpayServiceName}-service#g;s#{VERSION}#${version}#g'  webapps/${volpayServiceName}/${volpayServiceName}-deployment.tpl >  webapps/${volpayServiceName}/${volpayServiceName}-deployment-jenkins.yml"
    sh "more webapps/${volpayServiceName}/${volpayServiceName}-deployment-jenkins.yml"
    sh "oc apply -f webapps/${volpayServiceName}/${volpayServiceName}-deployment-jenkins.yml"

  }
}

def getJenkinsSACredentials(){
  stage ('Getting OC credentials '){
    withCredentials([[$class: 'StringBinding',
    credentialsId: 'jenkins-service-account',
    variable: 'authToken']]) {
        openshiftAuthToken = authToken
    }
  }
}

def checkoutCode () {
    stage ('Checkout SCM'){
      checkout scm
    }
}

def compileAndBuild () {
    stage 'Compile and Build Wars'
    echo 'Build Wars'
    sh 'mvn -B -DskipTests=true clean install'
}

def unitTest () {
    stage 'Unit tests'
    sh 'mvn test'
}

def copyRemoteWarFiles (stringEnvironment, remoteVM01, remoteVM02) {
    stage "Uploading files to " + stringEnvironment

    // Create remote folder
    echo stringEnvironment + " Upload - Creating remote folder " + remoteVM01 +":"+"${remote_server_folder}"
    sh "ssh -o StrictHostKeyChecking=no -i ${PEM_FILE_PATH} ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +" mkdir -p ${remote_server_folder}"
    
    echo stringEnvironment + " Upload - Creating remote folder ${remoteVM02}:${remote_server_folder}"
    sh "ssh -o StrictHostKeyChecking=no -i ${PEM_FILE_PATH} ${REMOTE_SERVER_UPLOAD_USERNAME}@${remoteVM02} mkdir -p ${remote_server_folder}"

    // Upload files
    echo stringEnvironment + " Upload - Uploading generated-wars/instruction.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/instruction.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +":${remote_server_folder}/instruction.war"
    
    echo stringEnvironment + " Upload - Uploading generated-wars/rest.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/rest.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +":${remote_server_folder}/rest.war"
    
    echo stringEnvironment + " Upload - Uploading generated-wars/scripts.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/scripts.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +":${remote_server_folder}/scripts.war"
    
    echo stringEnvironment + " Upload - Uploading generated-wars/transaction.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/transaction.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +":${remote_server_folder}/transaction.war"
    
    echo stringEnvironment + " Upload - Uploading generated-wars/volpayui.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/volpayui.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM01 +":${remote_server_folder}/volpayui.war"
    
    echo stringEnvironment + " Upload - Uploading generated-wars/sync.war"
    sh "scp -i ${PEM_FILE_PATH} ./generated-wars/sync.war ${REMOTE_SERVER_UPLOAD_USERNAME}@" + remoteVM02 +":${remote_server_folder}/sync.war"

    echo "Uploaded all files ${version} on " + stringEnvironment
}

def deployRemoteWarFiles (stringEnvironment, remoteVM01, remoteVM02) {
    stage "Deploy files in " + stringEnvironment
    
    echo stringEnvironment + " Deploy - Deleting Previous Version of instruction.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo rm -rf ${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/instruction'"
    
    echo stringEnvironment + " Deploy - Moving New Version of instruction.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo cp ${remote_server_folder}/instruction.war /${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/instruction.war'"
    
    echo stringEnvironment + " Deploy - Deleting Previous Version of rest.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo rm -rf ${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/rest'"
    
    echo stringEnvironment + " Deploy - Moving New Version of rest.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo cp ${remote_server_folder}/rest.war /${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/rest.war'"
    
    echo stringEnvironment + " Deploy - Deleting Previous Version of transaction.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo rm -rf ${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/transaction'"
    
    echo stringEnvironment + " Deploy - Moving New Version of transaction.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo cp ${remote_server_folder}/transaction.war /${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/transaction.war'"
    
    echo stringEnvironment + " Deploy - Deleting Previous Version of volpayui.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo rm -rf ${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/volpayui'"
    
    echo stringEnvironment + " Deploy - Moving New Version of volpayui.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM01+" 'sudo cp ${remote_server_folder}/volpayui.war /${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/volpayui.war'"
    
    echo stringEnvironment + " Deploy - Deleting Previous Version of sync.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM02+" 'sudo rm -rf ${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/sync'"
    
    echo stringEnvironment + " Deploy - Moving New Version of sync.war"
    sh "ssh -i ${PEM_FILE_PATH} -t ${REMOTE_SERVER_UPLOAD_USERNAME}@"+remoteVM02+" 'sudo cp ${remote_server_folder}/sync.war /${REMOTE_SERVER_TOMCAT_WEBAPPS_FOLDER}/sync.war'"
    
    echo "Deployed ${version} on " + stringEnvironment
}
