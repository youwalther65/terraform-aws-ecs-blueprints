# CI/CD with CodePipeline and Terraform

This solution blueprint creates a web-facing load balanced ECS service. There are two steps to deploying this service:

* Deploy the [core-infra](../core-infra/README.md). Note if you have already deployed the infra then you can reuse it as well.
* In this folder, copy the `terraform.tfvars.example` file to `terraform.tfvars` and update the variables.
* **NOTE:** Codestar notification rules require a **one-time** creation of a service-linked role. Please verify one exists or create the codestar-notification service-linked role.
  * `aws iam get-role --role-name AWSServiceRoleForCodeStarNotifications`

    ```An error occurred (NoSuchEntity) when calling the GetRole operation: The role with name AWSServiceRoleForCodeStarNotifications cannot be found.```
  *  If you receive the error above, please create the service-linked role with the `aws cli` below.
  * `aws iam create-service-linked-role --aws-service-name codestar-notifications.amazonaws.com`
  * Again, once this is created, you will not have to complete these steps for the other examples.  
* Now you can deploy this blueprint
```shell
terraform init -backend-config="key=${TEAM}/${ENV}-
${TARGET_DEPLOYMENT_SCOPE}/terraform.tfstate" -backend-config="region=$AWS_REGION"
-backend-config="bucket=${TF_BACKEND_CONFIG_PREFIX}-${ENV}" 
-backend-config="dynamodb_table=${TF_BACKEND_CONFIG_PREFIX}-lock-${ENV}"
-backend-config="encrypt=true"
```

<p align="center">
  <img src="../../docs/lb-service.png"/>
</p>

The `main.tf` focuses on creating the CI/CD pipeline using AWS CodePipeline and CodeBuild. This has following main components:

* **Please make sure you have stored the Github access token in AWS Secrets Manager as a plain text secret (not as key-value pair secret). This token is used to access the *application-code* repository and build images.**
* S3 bucket to store CodePipeline assets and Terraform State. The bucket is encrypted with AWS managed key.
* DynamoDB table for Terraform lock
* SNS topic for notifications from the pipeline
* CodeBuild for building container images
    * Needs the S3 bucket created above
    * IAM role for the build service
    * The *buildspec_path* is a key variable to note. It points to the [buildspec.yml](../../application-code/ecsdemo-frontend/templates/buildspec.yml) file which has all the instructions not only for building the container but also for pre-build processing and post-build artifacts preparation required for deployment.
    * A set of environment variables including repository URL and folder path.
* CodePipeline to listen for changes to the repository and trigger build and deployment.
    * Needs the S3 bucket created above
    * Github token from AWS Secrets Manager to access the repository with *application-code* folder
    * Repository owner
    * Repository name
    * Repository branch
    * SNS topic for notifications created above
    * The cluster and service names for deploying the tasks with new container images
    * The image definition file name which contains mapping of container name and container image. These are the containers used in the task.
    * IAM role

Note that the CodeBuild and CodePipeline services are provisioned and configured here. However, they primarily interact with the *application-code/ecsdemo-frontend* repository. CodePipeline is listening for changes and checkins to that repository. And CodeBuild is using the *Dockerfile* and *templates/* files from that application folder.
