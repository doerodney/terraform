# Terraform - A Tour and a Proposal
This document describes Terraform, an infrastructure-as-code (IAC) management tool from Hashicorp.  Content for this document is largely summarized/plagiarized from 'Terraform Up & Running - Writing Infrastructure as Code' by Yevgeniy Brikman. 

It also contains a high-level proposal for replacement of vCommander with Terraform.  

## High Level Description
Terraform is a command line tool that reads version-controllable text files in a directory and provisions infrastructure based upon the content of those text files.  It is able to provision infrastructure from many different [providers](https://www.terraform.io/docs/providers/index.html), including:
*   [Amazon Web Services](https://www.terraform.io/docs/providers/aws/index.html)
*   [Google Cloud Platform](https://www.terraform.io/docs/providers/google/index.html)
*   [vSphere, including vCenter Server and ESXi](https://www.terraform.io/docs/providers/vsphere/index.html)

### Syntax
Terraform uses **provider-specific** declarative syntax to provision infrastructure.  

This is an important point - Terraform is **NOT** an abstraction layer over all current and future providers.  

The syntax does not get into the "how" part of the problem - that is delegated to the provider.  Instead, the focus is on the "what" part of the problem.  As a captain on a ship might say "Make it so", and the crew implements the specific details to make that happen, the syntax in the terraform source files generally describes the desired outcome, and the terraform providers implement the specific solution.

Terraform files are written in Hashicorp Configuration Language (HCL), which looks sort of like Ruby, except where it doesn't.  It is subjectively clearer than, say, CloudFormation written in JSON.  Anybody in technology should be able to understand HCL.  See the Example Code section below for code samples.

### Workflow
The Terraform workflow includes these steps:
*   Create terraform source files in a directory.
*   Execute `terraform init` once to download required providers.
*   Execute `terraform plan` on the files in the directory.  This verifies the syntax in the source files, and produces a report of what changes Terraform will implement.
*   Execute `terraform apply` on the files in the directory.  This causes the infrastructure described in the source files to be provisioned.
    *   You will be prompted to confirm the intent to apply changes.
    *   As infrastructure is successfully provisioned, Terraform creates a 'state file' that describes the state of the infrastructure from a provisioning perspective.
*   Push Terraform code and state files to version control.  
    *   You want the master branch to represent what is deployed.
*   Implement changes to Terraform source files to implement changes to infrastructure.  This requires successive applications of `terraform plan` and `terraform apply`.    
*   Rigorously capture changes to Terraform source and state files to version control.
*   Execute `terraform destroy` to delete all the resources created by the terraform files in the directory.
    *   You will be prompted to confirm the intent to destroy.
 
### Team Usage
The workflow described above would work well for a team of one diligent person.  In that context, there would be no notion of these types of problems:
*   Forget to pull the latest source files and state files from version control prior to deployment (duh!).
*   Race conditions caused by multiple people starting simultaneous infrastructure changes.

To address the state file problems, there are numerous solutions that lock state files in shared, remote storage.  Hashicorp offers Terraform Cloud to manage state files and much more.  (Price information on this is well-guarded.)  In addition, Terragrunt is an Open Source solution that uses AWS DynamoDB to lock state files.  There are also S3 and GCP solutions available.  In summary, the state file problem has been solved; it is only necessary to select a solution.

To address the potential race condition, it is recommended to use a build server such as Jenkins to sequence build jobs.  An API that queues jobs could also solve this problem.  Hashicorp Cloud also solves this problem.

### Environments
Terraform operates on all terraform files (files with a .tf extension) in a directory.  This allows one to implement both environments and roles within environments simply by implementation of directory structures.  For example, this describes a file structure that implements stage and prod environments for a team:
*   stage
    *   vpc
    *   services
        *   frontend-app
        *   backend-app
            *   var.tf
            *   outputs.tf
            *   main.tf
    *   data-storage
        *   mysql
        *   redis
*   prod
    *   vpc
    *   services
    *   data-storage
*   mgt
    *   vpc
    *   services
        *   bastion-host
        *   jenkins
*   global
    *   iam
    *   s3     

### Example Code
When working with a new technology, there is no substitute for examples of working code.  To Learn a new technology is frequently a monkey-see-monkey-do process.  The Hashicorp site has numerous examples of working code for different providers:
*   [AWS](https://www.terraform.io/docs/providers/aws/r/instance.html)
*   [GCP](https://www.terraform.io/docs/providers/google/d/datasource_compute_instance.html) 
*   [vSphere](https://www.terraform.io/docs/providers/vsphere/index.html)

### Modules
Terraform implements a module architecture that allows code that is common between, say, environments to be implemented in a common module.  Specialization is acheived using input parameters (see var.tf above).

### Solving Harder Problems
Terraform implements a plugin architecture that implements Copy-Read-Update-Delete (CRUD) interface functions in the Go language.  Development of Terraform plugins is atypical, but the task does not appear to be daunting.  There are numerous examples of Open Source Terraform plugin code.

### Kubernetes
Terraform implements a [Kubernetes provider](https://www.terraform.io/docs/providers/kubernetes/index.html). 

### Post-Provision Configuration
Terraform does not come with a configuration management system.  Terraform provisions the infrastructure, then it is necessary to delegate to a configuration management system.

In AWS, it is possible using CloudFormation to define an AWS::CloudFormation::Init object that contains metadata that is used to configure the instance upon completion of provisioning.  To do this, it is necessary to: 
*       Define the metadata and add it as the Metadata attribute on the AWS::EC2::Instance object.
*       Define the UserData attribute on the AWS::EC2::Instance to invoke the cfn-init utility, which would interpret the metatdata content to: 
        *       Install packages
        *       Create groups
        *       Create users
        *       Download sources
        *       Create files
        *       Execute commands
        *       Configure services 

In AWS, this cfn-init process is available for Linux and Windows. 

Terraform does not implement this exact functionality.  Instead, it implements [cloud-init](https://cloudinit.readthedocs.io/en/latest/index.html) to do the post-provision configuration as part of its [template_cloudinit_config data source](https://www.terraform.io/docs/providers/template/d/cloudinit_config.html).  This enables these tasks to be performed by cloud-init:
*       Install packages with apt or yum.
*       Add users and groups
*       Install arbitrary packages
*       Create arbitrary files
*       Run commands on first boot
        *       Command could include commands to configure services
*       Install and run Chef recipes

See the [cloud-init Cloud config examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html#) for additional capabilities and examples.

It should be noted that cloud-init natively supports the usual Linux distributions.  It does not natively support Windows.  However, [Cloudbase-Init](https://cloudbase.it/cloudbase-init/) is an Open Source project that purports to be the Windows equivalent of cloud-init.  This demonstrates [Windows cloudbase-init usage on VMware](https://blogs.vmware.com/management/2019/01/windows-cloud-init-solution.html).  Commercial support for cloudbase-init is available.  

#### Other Options for Post-Provision Configuration
Terraform implements a provider for [Chef](https://www.terraform.io/docs/providers/chef/index.html).  This provider enables specification of a Chef run list to execute.

It is also possible to use [Terraform with Ansible](https://www.hashicorp.com/resources/ansible-terraform-better-together).  Here's how that could work:
1.  Use Hashicorp Packer to invoke Ansible to build machine images.
2.  Store machine images to a repository.
3.  Ansible calls Terraform to build instance(s) from a machine image.
4.  Invoke Ansible to do any final configuration. 

### Metrics
Terraform implements a provider for [Datadog](https://www.terraform.io/docs/providers/datadog/index.html).  This would enable a watchdog monitor to be created with the infrastructure stack.

### Anticipated Challenges
As always, there will difficulties associated with the usual suspects:
*   Firewall access
*   Stored credentials
*   Service accounts
*   Possible access to teams' AWS accounts

## Proposal - How We Could Replace vCommander With Terraform
It would be great if we could use Terraform to create infrastructure using generic descriptions, i.e.: 
*   Build an Ubuntu test server on AWS.
*   Build a fleet of N web servers load-balanced by an Nginx instance in the 990 datacenter.
*   Build a Big Query endpoint on GCP.  

This section provides a high-level description of how we might replace vCommander with Terraform as an infrastructure provisioning tool.

**WARNING:    This section may contain crazy talk**.

Steps in this process could include:
*   Develop a catalog of standard infrustructure configurations.
*   Create an allotment tracker.
*   Develop a build process.
*   Develop an onboarding process.
*   Find a way to convert existing vCommander builds to Terraform states (keep the Nobel committee in the loop for this). 

### Migration Decisions
*   Golden Images versus cloud-init configuration?
    *   Golden Images will still require configuration for DNS/Hostname specification.
*   If we are moving onto Terraform, what current infrastructure definitions should be moved to Terraform?
    *   vCenter virtual machines?
        *   Yes, because they were created by vCommander.
    *   CloudFormation resources?
        *  Low priority.  This could manufacture instability. 
    *   Resources deployed by Serverless, such as Lambda function definitions?
        *   Lowest priority.  Serverless, with its dockerize_* setting, adds value.

### Standard Infrastructure Configurationss
In soccer, a set piece is a pre-conceived play that a team polishes well in advance.  This is a valid analogy for infrustructure provisioning - identify the tasks that you will do most frequently, and have a polished response ready.  In this case, the polished response would be a Terraform module, all tested and ready to deploy.

To identify the most common configurations:
*   Review existing deployments.
*   Review existing vCommander workflows.
*   Ask around.
*   Publish a survey.
*   Review industry practice.

Examples of infrastructure configurations include:
*   Vanilla server with specified:
    *   Operating system
    *   Drive specifications
    *   Network location
*   Load-balanced web server fleet
*   Database server

### Develop an Allotment Tracker
This service would track a team's infrastructure allotment, and approve or disapprove an infrastructure build request.  Implementation in a highly-available database such as DynamoDB would be appropriate.  Upon completion of an apply or destroy task, it would update the team's allotment accordingly.

### Develop a Build Process
This is the important component that changes a user's minimally detailed request into a specific build request.  This process:
*   Validates that the request does not exceed the requesting team's allotment.
*   Selects the appropriate configuration (i.e., the vanilla Ubuntu server script).
*   Modifies the configuration script to reflect the request (i.e., change the count of vanilla Ubuntu servers from 0 to 2).
*   Creates a job to execute the Terraform execution.

The fact that this process must be able to process build requests for multiple infrastructure providers must be considered.  It might be implemented primarily as a REST endpoint (with excellent documentation), and then add a front end (Jenkins, GitLab CICD, whatever) as necessary. 

### Develop an Onboarding Process
Envision a directory structure that implements a subdirectory for each team.  The subdirectories under each team directory would be for each supported environment, and under that, the directories for each configuration (a large set of team/environment/configuration hierarchy members).  The primary role of the onboarding process would be to:
*   Create a directory structure of configurations for this team.
*   Create Terraform state files from the team's existing infrastructure created by vCommander/AWS/GCP.

### Transfer Management of Existing Infrastructure into Terraform
The key idea is to convert knowledge of infrastructure created by vCommander or CloudFormation to Terraform files (source and state). 

Terraform is able to [import existing infrastructure](https://www.terraform.io/docs/import/).  This process requires creation of a resource configuration block, to which the imported object will be mapped.  This is not a big deal as these are most likely going to be supported by newly-developed standard configurations.

The documentation on this feature indicates that a future version of Terraform will fully generate configuration.  It's on their radar.
   
a REST endpoint (with excellent documentation), and then add a front end (Jenkins, GitLab CICD, whatever) as necessary. 

### Develop an onboarding process
Envision a directory structure that implements a subdirectory for each team.  Subdirectories under each team directory would be created for each supported environment (prod, stage, dev, whatever), and under that, the directories for each configuration (a large set of team/environment/configuration hierarchy members).  The primary role of the onboarding process would be to:
*   Create a directory structure of configurations for this team.
*   Create Terraform state files from the team's existing infrastructure created by vCommander/AWS/GCP.

### Transfer Management of Existing Infrastructure into Terraform
The key idea is to convert knowledge of infrastructure created by vCommander or CloudFormation to Terraform files (source and state). 

Terraform is able to [import existing infrastructure](https://www.terraform.io/docs/import/).  This process requires creation of a resource configuration block, to which the imported object will be mapped.  This is not a big deal as these are most likely going to be supported by newly-developed standard configurations.

The documentation on this feature indicates that a future version of Terraform will fully generate configuration.  It's on their radar.
   