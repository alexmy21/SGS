# SGS
## (Self-Generative Systems)

This document serves as a technical overview of the development of the SGS project. For a comprehensive understanding of the project's development, it is advised to review the Introduction.md file.
Setting up development environment
I have chosen Visual Studio Code as my preferred IDE for several reasons:
It offers robust support for Julia, and the Jupyter Extension is particularly well-suited for handling Julia code. I find using notebooks as a testing environment to be especially convenient, at least from my perspective.
Of course, you are free to select any IDE that suits your preferences.

Project architecture include:
- SGS as a Julia framework: Streamlining operations and maintaining our commitment to an embeddable framework. 
- Redis: Serving as a computational engine, database, and search engine, Redis complements the SGS framework like a trusted tool—indispensable but unobtrusive, much like a cellphone that, while not a part of you, is always by your side.

## Installing Julia

The most recommended method for installing Julia is by utilizing the official Julia packaging. As of now, I am running Julia version 1.10.4.

## Installing Redis

I am utilizing the official Redis Docker image. For detailed guidance on how to use this image, please refer to the following article: [How to Use the Redis Docker Official Image](https://www.docker.com/blog/how-to-use-the-redis-docker-official-image/ ). 

To install it, execute the following Bash command:

    podman run -d --name redis-stack -p 6379:6379 -p 8001:8001 latest

This will install the Redis server and RedisInsight on port 8001. Once installed, you can access RedisInsight from your browser using the following link: http://localhost:8001/.

 If you prefer using the REPL interface, you will need to install the Redis server locally, which includes the redis-cli tool for starting the REPL.

## Cloning SGS project

    git clone https://github.com/alexmy21/SGS.git

## Open project in VS Code

    cd SGS
    code .

When you launch VS Code, open the terminal window and execute the following command:

    julia> using Pkg
    julia> Pkg.activate(".")

