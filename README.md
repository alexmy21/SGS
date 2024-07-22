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

# SGS Architecture

The core architecture of SGS is encapsulated within seven essential files:

1. **constants.jl** - This file houses a collection of constants essential for the HyperLogLog algorithm utilized in sets.jl.

2. **sets.jl** - This script implements HllSets, which are fundamental building blocks for all data structures within SGS.

3. **graph.jl** - This module provides an implementation of the Graph, which employs wrapped HllSets as nodes and represents edges as pairs of connected nodes. Additionally, it supports all set operations on nodes, adapted from the corresponding operations in HllSets (sets.jl).

4. **store.jl** - Serving as the data management hub, this module handles all data-related operations including data ingestion, processing scheduling, comments, and import/export functions. Essentially, store.jl facilitates all operations and tools necessary to support the SGS self-generative loop.

5. **search.jl** - This file offers support for search operations on Redisearch indices.

6. **tokens.jl** - This module is dedicated to managing token inverted indexes, linking datasets with their content treated as collections of tokens. All unique tokens extracted from the datasets are contained within Redisearch token indices.

7. **utils.jl** - A collection of general utility functions that are common across all files.

Among these, store.jl is notable for conducting the most complex processing by leveraging functions from other modules.

The strength of SGS lies in its meticulously engineered data architecture, which is specifically designed and tuned to meet the unique requirements of a self-reproducing loop.

## SGS data structure

The diagram provided below depicts the relationships among datasets, HllSets, and Graph Nodes.

![alt text](<Pics/Untitled presentation (1).jpg>)

It is crucial to note that there is a seamless transformation from an HllSet to a dataset within a Graph Node, and vice versa. 

This illustration serves as an informative infographic of the SGS data architecture.

![alt text](<Pics/Untitled presentation.jpg>)

Examining the diagram might easily give the mistaken impression that we are dealing with at least three distinct types of hashes. However, structurally, all hashes are identical; we categorize them into three groups based on Redis's naming conventions for hash names. Each hash name supports a compound structure consisting of multiple parts divided by a colon (:), referred to as prefixes.

RediSearch leverages this feature to associate search indices with hashes. For instance, the index 'b:nodes' is defined by a schema that links to 'b:node' as a hash prefix. RediSearch monitors all newly created hashes and, if a hash starts with a prefix specified in any of the indices, it will link this hash to the relevant index.

A particularly useful feature in Redis is the RENAME command. This command allows users to rename any key, including hash keys. By renaming a hash from 'b:node:some_sha1_id' to 'h:node:some_sha1_id', we effectively transfer this hash from the 'b:nodes' index to the 'h:nodes' index without physically moving any data. This exemplifies the concept of "zero copy."

As outlined in Introduction.md, the data acquisition process in SGS involves buffering all newly acquired data in the transaction stage before committing to the head. If the head already contains data intended for commitment, the commit module will first relocate the existing dataset to the tail by renaming it—this is another instance of a "zero copy" move. Subsequently, it places the new dataset into the head, again through renaming.

