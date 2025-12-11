# Project

The objective of this project is to build the cloud infrustructure proposed by @rishabkumar7 in [devops-qr-code](https://github.com/rishabkumar7/devops-qr-code) for an application that generates a QR code when a URL is given.

The application itself is composed of a backend written with Fast-API/Python, and a frontend with nextJS. these two components are contenerized with Docker, and pushed to DockerHub on every push through the use of Github Actions as depicted in the image below.

![](Images/qr-code-part1.jpg)

Regarding the deployment, a we used Terraform to deploy a kubernetes cluster. The yaml files of the kuberenetes cluster specify the lastet version fo the frontend and backend containers, so a simple rollout is needed to update the changes done to the source code of the API anf the frontend.

![](Images/qr-code-part1.jpg)

## Author

[Camilo Nuñez](https://github.com/camillonunez1998)

## License

[MIT](./LICENSE)