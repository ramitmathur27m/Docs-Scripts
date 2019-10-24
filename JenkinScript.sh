pipeline {

  agent {
        node { 
            label 'Agents-WODC-Linux'
        }
    }
  environment {
	  //maven home as it is configured in Global Configuration
       mvnHome = tool 'maven'
	   //scanner home as it is configured in Global Configuration
       scannerHome = tool 'SonarQubeTest'
	   //path to the gitlab project
	   gitURL = "git@git.fda.gov:FDA/CDER/BITM/OGDLabeling.git"
	   //The artifact name for the project
	   //artifactID = readMavenPom().getArtifactId()
	   //jenkins project path
	   projPath = "/data/jenkins/workspace/FDA/CDER/BITM/PRATs_Dev_Environment/Deploy_LRT"
	   //Prats server path for the shell script
	   pratsRunScriptPath = "/u01/app/bitm/ogdLabeling/RunOGDLabeling.sh"
	   //Prats path to bitm folder in the server
	   pathToServer1 = "fdsa_jenkins@fdslv21099-mgt.fda.gov:/u01/app/bitm"
	   pathToServer2 = "fdsa_jenkins@fdslv21100-mgt.fda.gov:/u01/app/bitm"
	   pathToServer3 = "fdsa_jenkins@fdslv21101-mgt.fda.gov:/u01/app/bitm"
	   //the email list 
	   emailList = "CDER-BITMTEAM@fda.hhs.gov;Ravinder.Singh@fda.hhs.gov"
	   
    }
    
 options{
	// remove older builds and artifacts if they exceed 15 builds
    buildDiscarder(logRotator(numToKeepStr: '100', artifactNumToKeepStr: '100'))
	//add the time stamp to the logs
	timestamps()
 }

   
   
   stages {
    stage("Git CheckOut") {
      steps {
        //CheckOut from the repository
		checkout([$class: 'GitSCM', 
		branches: [[name: 'features/multipleView']], //here you can enter branch name or SHA code
		userRemoteConfigs: [[credentialsId: 'svc.gitlab', 
		url: "${gitURL}"]]]) 
		//sh 'echo "Artifact name is $artifactID"'
	  }

    } 
	
	stage('Build Artifacts') {
		steps {
         nodejs('NodeJS 10.14.2') {
            sh "cd frontend && npm install && cd .."
            sh "${mvnHome}/bin/mvn clean package -Dmaven.test.skip=true "
            archiveArtifacts 'backend/target/*.jar, *.sh'          
                }
          }
	}

	stage('Unit Test') {
		steps {
		//running the unit tests
		sh "echo Unit Test!!!!"	
		}
		
	}

	// stage Sonar Scan
	stage('SonarQube Scan and Analysis') {
		steps  {	
		sh "echo Sonar Qube Scan!"
			 //   withSonarQubeEnv('SonarQubeTest') {
			//     //sh "${scannerHome}/bin/sonar-scanner"
			//     sh "${mvnHome}/bin/mvn sonar:sonar"
			  //  }
		}
	}
	// check the sonar quality Gate
	stage('Quality Gate Checks') {
		steps {	
		sh "echo Quality Gate check!"
			// sh 'sleep 10'
			// 	timeout(time: 1, unit: 'MINUTES') { // Just in case something goes wrong, pipeline will be killed after a timeout
			// 	    def qg = waitForQualityGate() // Reuse taskId previously collected by withSonarQubeEnv
			// 	    if (qg.status != 'OK') {
			// 		error "Pipeline aborted due to quality gate failure: ${qg.status}"
			// 		}else {
			// 		echo "Quality gate passed with result: ${qg.status}" 
			// 		}
			//     }
		}
	 }
	 
	 
		stage('Transfer LRT file to WODC Dev Servers') {
			steps {
				sshagent(['fdsa_jenkins_bitm']) {	
				sh "echo Trasnfering files to servers!"
				    //copy war file to all three servers
					sh 'scp -o StrictHostKeyChecking=no $projPath/backend/target/ogdlabeling-0.0.1-SNAPSHOT.jar $pathToServer1/ogdLabeling'
					sh 'scp -o StrictHostKeyChecking=no $projPath/backend/target/ogdlabeling-0.0.1-SNAPSHOT.jar $pathToServer2/ogdLabeling'
					sh 'scp -o StrictHostKeyChecking=no $projPath/backend/target/ogdlabeling-0.0.1-SNAPSHOT.jar $pathToServer3/ogdLabeling'
				    //copy shell script to all three servers
					sh 'scp -o StrictHostKeyChecking=no $projPath/RunOGDLabeling.sh $pathToServer1/ogdLabeling'
					sh 'scp -o StrictHostKeyChecking=no $projPath/RunOGDLabeling.sh $pathToServer2/ogdLabeling'
					sh 'scp -o StrictHostKeyChecking=no $projPath/RunOGDLabeling.sh $pathToServer3/ogdLabeling'
                    //copy word word Templates to all three servers
    
				}
			}
		}
		stage('Running new LRT service on DEV server') {
			steps {
				sshagent(['fdsa_jenkins_bitm']) {
					sh "echo executing the shell scripts!"
					sh 'ssh -o StrictHostKeyChecking=no fdsa_jenkins@fdslv21099-mgt.fda.gov  $pratsRunScriptPath dev'
					sh 'ssh -o StrictHostKeyChecking=no fdsa_jenkins@fdslv21100-mgt.fda.gov  $pratsRunScriptPath dev'
					sh 'ssh -o StrictHostKeyChecking=no fdsa_jenkins@fdslv21101-mgt.fda.gov  $pratsRunScriptPath dev'
					
				}
			}
		}
	
   }
   
   
    post {

        always {
			sh "echo Jenkins Job is Done"

        }
        success {
			sh "echo Sending Success Email!"
            notifyBuildPass("${emailList}")
        }

        failure {
			sh "echo Sending Failed Email!"
            notifyBuildFail("${emailList}")
          
        }
    }
   
   
   
   
}
 


 def notifyBuildPass(emailList) {


   // Send notifications

       emailext body: '''
		<!DOCTYPE html>
		<html>

		<head>
			<meta charset="UTF-8">
			<title>${ENV, var="JOB_NAME"}- ${BUILD_NUMBER}</title>
		</head>

		<body leftmargin="8" marginwidth="0" topmargin="8" marginheight="4" offset="0">
			<table width="95%" cellpadding="0" cellspacing="0" style="font-size: 11pt; font-family: Tahoma, Arial, Helvetica, sans-serif">
				<tr>
					<td>(Automatic email, DO NOT REPLY)</td>
				</tr>
				<tr>
					<td>
						<h2>
							<font color="#039b10">Build result - ${BUILD_STATUS}</font>
						</h2>
					</td>
				</tr>
				<tr>
					<td><br /> <b><font color="#0B610B">Build information</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<ul>
							<li>Project Name&nbsp;：&nbsp;${PROJECT_NAME}</li>
							<li>Build Number&nbsp;：&nbsp;${BUILD_NUMBER}</li>
							<li>Trigger Cause：&nbsp;${CAUSE}</li>
							<li>Build Logs：&nbsp;<a href="${BUILD_URL}console">${BUILD_URL}console</a></li>
							<li>Build&nbsp;&nbsp;Url&nbsp;：&nbsp;<a href="${BUILD_URL}">${BUILD_URL}</a></li>
							<li>Build List&nbsp;：&nbsp;<a href="${PROJECT_URL}ws">${PROJECT_URL}ws</a></li>
							<li>Project&nbsp;&nbsp;Url&nbsp;：&nbsp;<a href="${PROJECT_URL}">${PROJECT_URL}</a></li>
						</ul>
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Changes Since Last Successful Build:</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<ul>
							<li>Change History : <a href="${PROJECT_URL}changes">${PROJECT_URL}changes</a></li>
						</ul>
						${CHANGES_SINCE_LAST_SUCCESS,reverse=true, format="Changes for Build #%n:<br/>%c<br/>",showPaths=true,changesFormat="<pre>[%a]<br/>%m</pre>",pathFormat="&nbsp;&nbsp;&nbsp;&nbsp;%p"}
						<br/>
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Failed Test Results:</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<pre style="font-size: 11pt; font-family: Tahoma, Arial, Helvetica, sans-serif">$FAILED_TESTS</pre> <br />
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Build Log (Last 100 lines):</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<!-- <tr> <td>Test Logs (if test has ran): <a href="${PROJECT_URL}ws/TestResult/archive_logs/Log-Build-${BUILD_NUMBER}.zip">${PROJECT_URL}/ws/TestResult/archive_logs/Log-Build-${BUILD_NUMBER}.zip</a> <br /> <br /> </td> </tr> -->
				<tr>
					<td>
						<pre style=\'line-height: 22px; display: block; color: #333; font-family: Monaco,Menlo,Consolas,"Courier New",monospace; padding: 10.5px; margin: 0 0 11px; font-size: 13px; word-break: break-all; word-wrap: break-word; white-space: pre-wrap; background-color: #f5f5f5; border: 1px solid #ccc; border: 1px solid rgba(0,0,0,.15); -webkit-border-radius: 4px; -moz-border-radius: 4px; border-radius: 4px;\'>
						${BUILD_LOG, maxLines=100, escapeHtml=true}
						</pre>
					</td>
				</tr>
			</table>
		</body>

		</html>''', subject: 'DO NOT REPLY: JENKINS Build Server Notification [${BUILD_STATUS}]${JOB_NAME} Build #${BUILD_NUMBER}', to: emailList

     

 }
 
 def notifyBuildFail(emailList) {


   // Send notifications

       emailext body: '''
		<!DOCTYPE html>
		<html>

		<head>
			<meta charset="UTF-8">
			<title>${ENV, var="JOB_NAME"}- ${BUILD_NUMBER}</title>
		</head>

		<body leftmargin="8" marginwidth="0" topmargin="8" marginheight="4" offset="0">
			<table width="95%" cellpadding="0" cellspacing="0" style="font-size: 11pt; font-family: Tahoma, Arial, Helvetica, sans-serif">
				<tr>
					<td>(Automatic email, DO NOT REPLY)</td>
				</tr>
				<tr>
					<td>
						<h2>
							<font color="#FF001E">Build result - ${BUILD_STATUS}</font>
						</h2>
					</td>
				</tr>
				<tr>
					<td><br /> <b><font color="#0B610B">Build information</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<ul>
							<li>Project Name&nbsp;：&nbsp;${PROJECT_NAME}</li>
							<li>Build Number&nbsp;：&nbsp;${BUILD_NUMBER}</li>
							<li>Trigger Cause：&nbsp;${CAUSE}</li>
							<li>Build Logs：&nbsp;<a href="${BUILD_URL}console">${BUILD_URL}console</a></li>
							<li>Build&nbsp;&nbsp;Url&nbsp;：&nbsp;<a href="${BUILD_URL}">${BUILD_URL}</a></li>
							<li>Build List&nbsp;：&nbsp;<a href="${PROJECT_URL}ws">${PROJECT_URL}ws</a></li>
							<li>Project&nbsp;&nbsp;Url&nbsp;：&nbsp;<a href="${PROJECT_URL}">${PROJECT_URL}</a></li>
						</ul>
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Changes Since Last Successful Build:</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<ul>
							<li>Change History : <a href="${PROJECT_URL}changes">${PROJECT_URL}changes</a></li>
						</ul>
						${CHANGES_SINCE_LAST_SUCCESS,reverse=true, format="Changes for Build #%n:<br/>%c<br/>",showPaths=true,changesFormat="<pre>[%a]<br/>%m</pre>",pathFormat="&nbsp;&nbsp;&nbsp;&nbsp;%p"}
						<br/>
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Failed Test Results:</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<tr>
					<td>
						<pre style="font-size: 11pt; font-family: Tahoma, Arial, Helvetica, sans-serif">$FAILED_TESTS</pre> <br />
					</td>
				</tr>
				<tr>
					<td>
						<b><font color="#0B610B">Build Log (Last 100 lines):</font></b>
						<hr size="2" width="100%" align="center" />
					</td>
				</tr>
				<!-- <tr> <td>Test Logs (if test has ran): <a href="${PROJECT_URL}ws/TestResult/archive_logs/Log-Build-${BUILD_NUMBER}.zip">${PROJECT_URL}/ws/TestResult/archive_logs/Log-Build-${BUILD_NUMBER}.zip</a> <br /> <br /> </td> </tr> -->
				<tr>
					<td>
						<pre style=\'line-height: 22px; display: block; color: #333; font-family: Monaco,Menlo,Consolas,"Courier New",monospace; padding: 10.5px; margin: 0 0 11px; font-size: 13px; word-break: break-all; word-wrap: break-word; white-space: pre-wrap; background-color: #f5f5f5; border: 1px solid #ccc; border: 1px solid rgba(0,0,0,.15); -webkit-border-radius: 4px; -moz-border-radius: 4px; border-radius: 4px;\'>
						${BUILD_LOG, maxLines=100, escapeHtml=true}
						</pre>
					</td>
				</tr>
			</table>
		</body>

		</html>''', subject: 'DO NOT REPLY: JENKINS Build Server Notification [${BUILD_STATUS}]${JOB_NAME} Build #${BUILD_NUMBER}', to: emailList

     

 }