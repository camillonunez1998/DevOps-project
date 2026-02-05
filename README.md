# Project


The objective of this project is to design and develop a minimal set up required for the continuous integration and continuous deployment (CI/CD) of a web application.


The app —sourced from @rishabkumar7 in [devops-qr-code](https://github.com/rishabkumar7/devops-qr-code)— consists on a Next.js frontend that receives a URL, and a Python/FastAPI backend that returns a QR code.


## Running the application locally


The diagram below depicts the interaction of the different components of the application.


![Local structure of the application](Images/devops-project-local.svg)


To run it locally without docker, please refer to the instructions in [devops-qr-code](https://github.com/rishabkumar7/devops-qr-code) repository.


**Note:** Before starting the application locally, you must update the API endpoint to the local development environment. This configuration is located in `front-end-nextjs/src/app/page.js`, specifically within the lines highlighted below:


![API endpoint](Images/API-endpoint.png)


### Dockerization


Both the backend and frontend have been containerized using Docker. A GitHub Actions workflow was implemented to automate the build and push process to DockerHub. This pipeline triggers on every push to the master branch, ensuring that the latest images are always available, as illustrated in the diagram below. The build and push is triggered only in the components with changes registered in git.


![CI/CD and dockerization](Images/CI-dockerization.svg)


To run the application locally with docker, run the command `docker compose up`.

**Note:** Since the `compose.yaml` file is located in the project's root (`./`), there must be a `.env` file containing the AWS credentials for the API also in the project's root, following the structure of `./api/.env.example`.


## Deployment in cloud


The application is hosted on AWS, with the infrastructure fully defined via Terraform. The following diagram depicts the cloud resources and network configuration used to expose the application to the internet:


![Terraform](Images/terraform.svg)


To provision the cloud infrastructure, navigate to the `./infrastructure/` directory and execute the following commands:


- `terraform init`
- `terraform apply`


Once you have done this your AWS VPC will be ready to host the application. In order to do so, follow the steps:
- Update the API endpoint in `front-end-nextjs/src/app/page.js`, so that the IP matches the public IP of the EC2 instance.
- Push the changes with git. GitHub Actions will build and push to DockerHub the new image of the frontend.
- Connect to the EC2 instance with Instance Connect or through ssh with the command `ssh -i ~/.ssh/id_rsa_aws ec2-user@<public-IP>`
- The `compose.yaml` file is located in the instance's home directory. You must uncomment the environment variables within the file to proceed. You'll need sudo to make changes in this file.
- Execute `docker compose up -d`.


Once these steps are completed, the frontend will be active on port 80. To access the application, simply navigate to the EC2 instance's public IP address in your web browser.

## Deployment in cloud with EKS

- Within the ./infrastructure directory, add the AWS credentials the API requires to access the S3 bucket in a file called `.env` as specified in the *Authentication & Security* section. 

- To authenticate the certificate of our cluster in AWS, add the endpoint of its API server, and update your local file `~/.kube/config`, run the command

	`aws eks update-kubeconfig --region eu-north-1 --name devops-project`

- Within the infrastructure directory, deploy the application using Kustomize

	`kubectl apply -k .`

- Obtain the IP of the frontend by checking the services in your cluster

	`kubectl get services`

	now you are able to use the app seamlessly.

- To stop the deployment, first destroy the k8s kustomization with 

	`kubectl delete -k .`

	and then the cloud infrastructure with

	`terraform destroy`

	you will need the same pair of keys you used to apply your infrastructure to destroy it, otherwise you'll have to destroy it manually.


### Monitoring and Observability

We used the Kube-Prometheus-Stack for the purpose of observability.

- Create a namespace in your cluster

	`kubectl create namespace monitoring`

- Install helm

	`sudo install helm --classic`

- Add the official repo

	`helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
	
	`helm repo update`

- Install the stack

	`helm install my-stack prometheus-community/kube-prometheus-stack --namespace monitoring`

- By default, Grafana installs as a ClusterIP service type (only visible inside the cluster). to see it from your browser, change the service type into Load Balancer

	`kubectl patch svc my-stack-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'`

- Get the IP of the Load Balancer from the service sin the namespaces. Once you paste it in the browser, you use the username `admin` and obtain the password Helm stored in the cluster with 

	`kubectl get secret --namespace monitoring my-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo`

- Choose the Dashboard ID 12740 (classic for kubernetes).



## Authentication & Security


AWS credentials are required by Terraform and the backend. Terraform utilizes the credentials stored in `~/.aws/credentials` on your local machine to provision the AWS cloud infrastructure. This file is expected to be in the format:

`[default]`<br>
`aws_access_key_id = *****************`<br>
`aws_secret_access_key = ******************`

And the minimal permissions required .json file is:

`{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "S3Management",
			"Effect": "Allow",
			"Action": [
				"s3:CreateBucket",
				"s3:DeleteBucket",
				"s3:Get*",
				"s3:ListBucket",
				"s3:PutBucketPolicy",
				"s3:DeleteBucketPolicy",
				"s3:PutBucketPublicAccessBlock",
				"s3:PutBucketOwnershipControls",
				"s3:PutBucketAcl",
				"s3:PutLifecycleConfiguration",
				"s3:PutObject"
			],
			"Resource": [
				"arn:aws:s3:::qr-code-bucket-camilo",
				"arn:aws:s3:::qr-code-bucket-camilo/*"
			]
		},
		{
			"Sid": "IAMAndOIDCManagement",
			"Effect": "Allow",
			"Action": [
				"iam:CreateRole",
				"iam:DeleteRole",
				"iam:GetRole",
				"iam:List*",
				"iam:PassRole",
				"iam:TagRole",
				"iam:UntagRole",
				"iam:PutRolePolicy",
				"iam:AttachRolePolicy",
				"iam:DetachRolePolicy",
				"iam:DeleteRolePolicy",
				"iam:GetRolePolicy",
				"iam:CreateInstanceProfile",
				"iam:DeleteInstanceProfile",
				"iam:GetInstanceProfile",
				"iam:AddRoleToInstanceProfile",
				"iam:RemoveRoleFromInstanceProfile",
				"iam:CreatePolicy",
				"iam:DeletePolicy",
				"iam:GetPolicy",
				"iam:GetPolicyVersion",
				"iam:TagPolicy",
				"iam:CreateOpenIDConnectProvider",
				"iam:GetOpenIDConnectProvider",
				"iam:DeleteOpenIDConnectProvider",
				"iam:TagOpenIDConnectProvider"
			],
			"Resource": [
				"arn:aws:iam::973076296292:role/devops-project*",
				"arn:aws:iam::973076296292:role/green-*",
				"arn:aws:iam::973076296292:role/eks-*",
				"arn:aws:iam::973076296292:role/aws-service-role/*",
				"arn:aws:iam::973076296292:policy/devops-project*",
				"arn:aws:iam::973076296292:instance-profile/devops-project*",
				"arn:aws:iam::973076296292:instance-profile/green-*",
				"arn:aws:iam::973076296292:oidc-provider/*",
				"arn:aws:iam::aws:policy/*"
			]
		},
		{
			"Sid": "KMSLogsSSMAndAutoscaling",
			"Effect": "Allow",
			"Action": [
				"kms:CreateKey",
				"kms:DescribeKey",
				"kms:GetKeyPolicy",
				"kms:GetKeyRotationStatus",
				"kms:ListResourceTags",
				"kms:ScheduleKeyDeletion",
				"kms:TagResource",
				"kms:EnableKeyRotation",
				"kms:CreateAlias",
				"kms:DeleteAlias",
				"kms:ListAliases",
				"logs:CreateLogGroup",
				"logs:DescribeLogGroups",
				"logs:ListTagsForResource",
				"logs:TagResource",
				"logs:PutRetentionPolicy",
				"logs:DeleteLogGroup",
				"ssm:GetParameter",
				"ssm:GetParameters",
				"autoscaling:Describe*",
				"autoscaling:TerminateInstanceInAutoScalingGroup",
				"autoscaling:UpdateAutoScalingGroup"
			],
			"Resource": "*"
		},
		{
			"Sid": "EC2InfrastructureAndLaunchTemplates",
			"Effect": "Allow",
			"Action": [
				"ec2:CreateVpc",
				"ec2:DeleteVpc",
				"ec2:Describe*",
				"ec2:CreateSubnet",
				"ec2:DeleteSubnet",
				"ec2:CreateInternetGateway",
				"ec2:DeleteInternetGateway",
				"ec2:AttachInternetGateway",
				"ec2:DetachInternetGateway",
				"ec2:CreateRouteTable",
				"ec2:DeleteRouteTable",
				"ec2:CreateRoute",
				"ec2:DeleteRoute",
				"ec2:AssociateRouteTable",
				"ec2:DisassociateRouteTable",
				"ec2:ModifyVpcAttribute",
				"ec2:ModifySubnetAttribute",
				"ec2:CreateSecurityGroup",
				"ec2:DeleteSecurityGroup",
				"ec2:AuthorizeSecurityGroupIngress",
				"ec2:AuthorizeSecurityGroupEgress",
				"ec2:RevokeSecurityGroupIngress",
				"ec2:RevokeSecurityGroupEgress",
				"ec2:CreateTags",
				"ec2:RunInstances",
				"ec2:TerminateInstances",
				"ec2:CreateLaunchTemplate",
				"ec2:DeleteLaunchTemplate",
				"ec2:CreateLaunchTemplateVersion",
				"ec2:ModifyLaunchTemplate"
			],
			"Resource": "*"
		},
		{
			"Sid": "EKSClusterManagement",
			"Effect": "Allow",
			"Action": [
				"eks:*"
			],
			"Resource": "*"
		}
	]
}`

 On the other hand, the backend requires credentials to be defined as environment variables in `./api/.env` to access the S3 bucket. These credentials must be given in the format:
 
 `AWS_ACCESS_KEY=Your-AWS-Access-Key
AWS_SECRET_KEY=Your-AWS-Secret-Access-Key`

And the minimal permissions required .json file is:

`{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::qr-code-bucket-camilo/*"
        }
    ]
}`

  In accordance with security best practices, two different users were defined for each one of these needs with both sets of credentials following the Principle of Least Privilege (PoLP).

Furthermore, Terraform will look for an SSH key pair in `~/.ssh/` named `id_rsa_aws`. These keys are required for the SSH tunnel used to communicate securely with the EC2 instance.





## Author


[Camilo Nuñez](https://github.com/camillonunez1998)


## License


[MIT](./LICENSE)