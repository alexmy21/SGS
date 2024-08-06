# README.md for SGS Project

## Overview

This document serves as a technical overview of the development process for the SGS project. For a more comprehensive understanding of the project's evolution and objectives, we recommend reviewing the accompanying `Introduction.md` file.

**Note:** This document is currently a work in progress, and we anticipate adding new sections and editing existing content in the near future.

## Setting Up the Development Environment

For the development of the SGS project, Visual Studio Code has been selected as the preferred Integrated Development Environment (IDE). This choice is based on its robust support for the Julia programming language, particularly through the Jupyter Extension, which facilitates effective management of Julia code. The use of notebooks as a testing environment is especially convenient for development purposes. However, developers are encouraged to utilize any IDE that aligns with their personal preferences.

### Project Components

- **SGS as a Julia Framework:** The SGS framework is designed to streamline operations while ensuring our commitment to an embeddable framework.
- **Redis:** Serving as a computational engine, database, and search engine, Redis complements the SGS framework by providing essential functionalities—similar to a reliable tool that is always at your side, yet unobtrusive.

### Installing Julia

The recommended method for installing Julia is through the official Julia packaging. As of this writing, the project is utilizing Julia version 1.10.4.

### Installing Redis

The official Redis Docker image is being used for this project. For detailed instructions on how to utilize this image, please refer to the following article: [How to Use the Redis Docker Official Image](https://www.docker.com/blog/how-to-use-the-redis-docker-official-image/).

To install Redis, execute the following Bash command:

```bash
podman run -d --name redis-stack -p 6379:6379 -p 8001:8001 latest
```

This command will set up the Redis server and RedisInsight, which can be accessed from your browser at the following link: [http://localhost:8001](http://localhost:8001). If you prefer to use the REPL interface, you will need to install the Redis server locally, which includes the `redis-cli` tool for initiating the REPL.

### Cloning the SGS Project

To clone the SGS project repository, use the following command:

```bash
git clone https://github.com/alexmy21/SGS.git
```

### Opening the Project in Visual Studio Code

Navigate into the cloned project directory and open it in Visual Studio Code:

```bash
cd SGS
code .
```

Upon launching Visual Studio Code, open the terminal and execute the following commands:

```julia
julia> using Pkg
julia> Pkg.activate(".")
```

## SGS Architecture

The core architecture of SGS is encapsulated within eight essential files:

- **constants.jl:** Contains constants crucial for the HyperLogLog algorithm employed in `sets.jl`.
- **sets.jl:** Implements `HllSets`, which serve as fundamental building blocks for all data structures within SGS.
- **entity.jl:** Introduces the `Entity` structure, which encapsulates metadata using `HllSets`, building on the work of Mike Saint-Antoine's SimpleGrad.jl, adapted from Andrey Karpathy's MicroGrad project. Our approach replaces traditional numerical embeddings with `HllSets`.
- **graph.jl:** Implements the Graph structure, utilizing wrapped `HllSets` as nodes and representing edges as pairs of connected nodes, while supporting all set operations on nodes.
- **store.jl:** Acts as the data management hub, overseeing all data-related operations, including ingestion, processing scheduling, commits, and import/export functions.
- **search.jl:** Provides support for search operations on Redisearch indices.
- **tokens.jl:** Manages token inverted indexes, linking datasets with their content, treated as collections of tokens.
- **utils.jl:** Contains general utility functions common across all files.

Among these, `store.jl` is notable for performing complex processing by leveraging functions from other modules. The strength of SGS lies in its meticulously engineered data architecture, specifically designed and optimized to meet the unique requirements of a self-reproducing loop.

## Metadata as the Foundation of SGS

The SGS framework adopts a novel approach by utilizing metadata to depict elements in a more abstract manner. This shift enhances the logic used in AI model development, moving beyond simplistic cause-and-effect relationships to a more nuanced understanding of correlations. Metadata organizes elements into groups that share semantic similarities, providing a robust framework for AI training methodologies.

HllSets serve as embeddings for these groups, represented as fixed-size bit-vectors, specifically a 2-dimensional Tensor (64, P). This allows for versatile comparisons across various metrics, fulfilling the primary objective of embedding while offering additional advantages over traditional numerical representations.

## SGS Data Structure

### Building Blocks

The relationships among datasets, `HllSets`, and Graph Nodes are depicted in the accompanying diagram. Notably, there exists a seamless transformation from an `HllSet` to a dataset within a Graph Node and vice versa.

### General Overview

The accompanying infographic illustrates the SGS data architecture. It is important to note that while the structure may suggest multiple types of hashes, all hashes are structurally identical. They are categorized into three groups based on Redis's naming conventions for hash names, with distinct prefixes indicating the life cycle stage of the node instance.

## Redis as an Integral Part of SGS

Redis was selected as the data management tool for SGS after thorough evaluation. Its integration with Java-based projects over the past decade has proven effective in managing runtime data. Redisearch, an extension of Redis, utilizes naming conventions to link search indices with hashes, facilitating seamless data management.

## Testing SGS Modules

### Module: sets.jl

The testing process for the `sets.jl` module includes configuring the environment and generating `HllSets` to experiment with various operations. The effectiveness of the HyperLogLog Set approximation is demonstrated through cardinality estimation and fundamental set properties.

### Module: entity.jl

The `entity.jl` module introduces the `Entity` structure, which encapsulates metadata using `HllSets`. Several static and dynamic structure operations have been implemented to facilitate the creation and management of entities.

### Module: tokens.jl and graph.jl

These modules are designed to complement each other, leveraging graph structures and `HllSets` for their respective functionalities. The integration of these modules enhances the overall capabilities of the SGS framework.

## Conclusion

This document outlines the foundational aspects of the SGS project, including its architecture, development environment setup, and core modules. As the project continues to evolve, further updates and enhancements will be documented to provide clarity and guidance for developers and stakeholders.

For additional insights and updates, please refer to the `README_detailed.md`, `Introduction.md` files and the notebook's files.
