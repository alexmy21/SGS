# SGS

## (Self-Generative Systems)

>This document provides a technical overview of the development process for the SGS project. For a more in-depth understanding of the project's evolution, we recommend reviewing the Introduction.md file.

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

## SGS Architecture

The core architecture of SGS is encapsulated within seven essential files:

1. **constants.jl** - This file houses a collection of constants essential for the HyperLogLog algorithm utilized in sets.jl.

2. **sets.jl** - This script implements HllSets, which are fundamental building blocks for all data structures within SGS.

3. **graph.jl** - This module provides an implementation of the Graph, which employs wrapped HllSets as nodes and represents edges as pairs of connected nodes. Additionally, it supports all set operations on nodes, adapted from the corresponding operations in HllSets (sets.jl).

4. **store.jl** - Serving as the data management hub, this module handles all data-related operations including data ingestion, processing scheduling, commits, and import/export functions. Essentially, store.jl facilitates all operations and tools necessary to support the SGS self-generative loop.

5. **search.jl** - This file offers support for search operations on Redisearch indices.

6. **tokens.jl** - This module is dedicated to managing token inverted indexes, linking datasets with their content treated as collections of tokens. All unique tokens extracted from the datasets are contained within Redisearch token indices.

7. **utils.jl** - A collection of general utility functions that are common across all files.

Among these, store.jl is notable for conducting the most complex processing by leveraging functions from other modules.

The strength of SGS lies in its meticulously engineered data architecture, which is specifically designed and tuned to meet the unique requirements of a self-reproducing loop.

## SGS data structure

### Building blocks

The diagram provided below depicts the relationships among datasets, HllSets, and Graph Nodes.

![alt text](<Pics/Untitled presentation (1).jpg>)

It is crucial to note that there is a seamless transformation from an HllSet to a dataset within a Graph Node, and vice versa.

### Data Structure. General overview

This illustration serves as an informative infographic of the SGS data architecture.

![alt text](<Pics/Untitled presentation.jpg>)

Examining the diagram might easily give the mistaken impression that we are dealing with at least three distinct types of hashes. However, structurally, all hashes are identical; we categorize them into three groups based on Redis's naming conventions for hash names. Each hash name supports a compound structure consisting of multiple parts divided by a colon (:), referred to as prefixes.

### Utilizing Redis benefits

RediSearch leverages Redis naming convention feature to associate search indices with Redis hashes. For instance, the index 'b:nodes' is defined by a schema that links to 'b:node' as a hash prefix. RediSearch monitors all newly created hashes and, if a hash starts with a prefix specified in any of the indices, it will link this hash to the relevant index.

A particularly useful feature in Redis is the RENAME command. This command allows users to rename any key, including hash keys. By renaming a hash from 'b:node:some_sha1_id' to 'h:node:some_sha1_id', we effectively transfer this hash from the 'b:nodes' index to the 'h:nodes' index without physically moving any data. This exemplifies the concept of "zero copy."

As outlined in Introduction.md, the data acquisition process in SGS involves buffering all newly acquired data in the transaction stage before committing to the head. If the head already contains data intended for commitment, the commit module will first relocate the existing dataset to the tail by renaming it—this is another instance of a "zero copy" move. Subsequently, it places the new dataset into the head, again through renaming.

## Testing SGS modules

### Module: sets.jl

Below are excerpts from the hll_sets.ipynb Jupyter notebook.
In the initial cell, we are configuring the environment to execute the upcoming code:

    using Random
    using FilePathsBase: extension, Path
    include("src/sets.jl")

    import .HllSets as set

Let's generate a few HlSets to experiment with.

    # Initialize test HllSets
    hll1 = set.HllSet{10}()
    hll2 = set.HllSet{10}()
    hll3 = set.HllSet{10}()
    hll4 = set.HllSet{10}()
    hll5 = set.HllSet{10}()

    # Generate datasets from random strings
    s1 = Set(randstring(7) for _ in 1:10)
    s2 = Set(randstring(7) for _ in 1:15)
    s3 = Set(randstring(7) for _ in 1:100)
    s4 = Set(randstring(7) for _ in 1:20)
    s5 = Set(randstring(7) for _ in 1:130)

    # Add datasets to HllSets
    set.add!(hll1, s1)
    set.add!(hll2, s2)
    set.add!(hll3, s3)
    set.add!(hll4, s4)
    set.add!(hll5, s5)

The following code will demonstrate the effectiveness of HyperLogLog Set approximation in accurately estimating set cardinality:

    # Print cardinality of datasets and HllSets side by side
    print(length(s1), " : ", count(hll1), "\n")
    print(length(s2), " : ", count(hll2), "\n")
    print(length(s3), " : ", count(hll3), "\n")
    print(length(s4), " : ", count(hll4), "\n")
    print(length(s5), " : ", count(hll5), "\n\n")
    # union
    print(length(s1 ∪ s2 ∪ s3 ∪ s4 ∪ s5), " : ", count(hll1 ∪ hll2 ∪ hll3 ∪ hll4 ∪ hll5), "\n")
    # intersection
    print(length(s1 ∩ s2 ∩ s3 ∩ s4 ∩ s5), " : ", count(hll1 ∩ hll2 ∩ hll3 ∩ hll4 ∩ hll5), "\n")

Here is an output demonstrating that the approximation using HllSet is indeed quite effective:

    10 : 10
    15 : 15
    100 : 98
    20 : 19
    130 : 129

    275 : 269
    0 : 1

It is evident that utilizing set operations on HllSets results in a slight degradation of approximation: 275 versus 269 for union and 0 versus 1 for intersection.

Proving Fundamental Set properties
Fundamental properties:
Commutative property

1. (A ∪ B) = (B ∪ A)
2. (A ∩ B) = (B ∩ A)

Associative property

3. (A ∪ B) ∪ C) = (A ∪ (B ∪ C))
4. (A ∩ B) ∩ C) = (A ∩ (B ∩ C))

Distributive property:

5. ((A ∪ B) ∩ C) = (A ∩ C) ∪ (B ∩ C)
6.  ((A ∩ B) ∪ C) = (A ∪ C) ∩ (B ∪ C)

Identity:

7.  (A ∪ Z) = A   
8.  (A ∩ U) = A
Some additional laws:

Idempotent laws:

1. (A ∪ A) = A 
3. (A ∩ A) = A

A = hll_1
B = hll_2
C = hll_3

    # Defining local empty Set
    Z = set.HllSet{10}()

    # Defining local universal Set
    U = A ∪ B ∪ C

    print("\n 1. (A ∪ B) = (B ∪ A): ", count(A ∪ B) == count(B ∪ A))
    print("\n 2. (A ∩ B) = (B ∩ A): ", count(A ∩ B) == count(B ∩ A))
    print("\n 3. (A ∪ B) ∪ C) = (A ∪ (B ∪ C)): ", count((A ∪ B) ∪ C) == count(A ∪ (B ∪ C)))
    print("\n 4. (A ∩ B) ∩ C) = (A ∩ (B ∩ C)): ", count((A ∩ B) ∩ C) == count(A ∩ (B ∩ C)))
    print("\n 5. ((A ∪ B) ∩ C) = (A ∩ C) ∪ (B ∩ C): ", count(((A ∪ B) ∩ C)) == count((A ∩ C) ∪ (B ∩ C)))
    print("\n 6. ((A ∩ B) ∪ C) = (A ∪ C) ∩ (B ∪ C): ", count(((A ∩ B) ∪ C)) == count((A ∪ C) ∩ (B ∪ C)))
    print("\n 7. (A ∪ Z) = A: ", count(A ∪ Z) == count(A))
    print("\n 8. (A ∩ U) = A: ", count(A ∩ U) == count(A))
    print("\n 9. (A ∪ A) = A: ", count(A ∪ A) == count(A))
    print("\n10. (A ∩ A) = A: ", count(A ∩ A) == count(A))

Here is the output demonstrating that all the specified set laws are satisfied:

     1. (A ∪ B) = (B ∪ A): true
     2. (A ∩ B) = (B ∩ A): true
     3. ((A ∪ B) ∪ C) = (A ∪ (B ∪ C)): true
     4. ((A ∩ B) ∩ C) = (A ∩ (B ∩ C)): true
     5. ((A ∪ B) ∩ C) = (A ∩ C) ∪ (B ∩ C): true
     6. ((A ∩ B) ∪ C) = (A ∪ C) ∩ (B ∪ C): true
     7. (A ∪ Z) = A: true
     8. (A ∩ U) = A: true
     9. (A ∪ A) = A: true
    10. (A ∩ A) = A: true

### Module: graph.jl

The `graph.jl` module stands as the cornerstone of the SGS platform, encapsulating its core functionalities. In this section, we will delve into the data structures and fundamental functions integral to this module, drawing insights from the `hll_graph.ipynb` Jupyter notebook.

In the initial cell, we are configuring the environment:

    include("src//graph.jl")
    using ..HllGraph
    using ..HllSets
    using Redis
    using EasyConfig
    using UUIDs
    using Random

    conn = Redis.RedisConnection()

Next, let's proceed with creating some HllSets:

    # Initialize test HllSets
    hll1 = HllSets.HllSet{10}()
    hll2 = HllSets.HllSet{10}()
    hll3 = HllSets.HllSet{10}()
    hll4 = HllSets.HllSet{10}()
    hll5 = HllSets.HllSet{10}()

    # Add datasets to HllSets
    HllSets.add!(hll1, s1)
    HllSets.add!(hll2, s2)
    HllSets.add!(hll3, s3)
    HllSets.add!(hll4, s4)
    HllSets.add!(hll5, s5)

We are now ready to create some graph nodes:

    node1 = HllGraph.Node(HllSets.id(hll1), ["node1"], HllSets.dump(hll1))
    node2 = HllGraph.Node(HllSets.id(hll2), ["node2"], HllSets.dump(hll2))
    node3 = HllGraph.Node(HllSets.id(hll3), ["node3"], HllSets.dump(hll3))
    node4 = HllGraph.Node(HllSets.id(hll4), ["node4"], HllSets.dump(hll4))
    node5 = HllGraph.Node(HllSets.id(hll5), ["node5"], HllSets.dump(hll5))

    graph = HllGraph.Graph([node1, node2, node3, node4, node5], [])

Here is the output generated by this code:

    Main.HllGraph.Graph(
    Main.HllGraph.Node[
    Node(5c94a3ac94480f7b4c0e40294231b7ada6323388; ["node1"]; 10), Node(abb71c6a26339830f1d58fe63c09e5caae3b3705; ["node2"]; 16), Node(ce7cd9b5aa1aa0f26d571fa21346badb8080bb08; ["node3"]; 100), Node(6648e755fa0d54e4122227b2ab4b81d1b768d6fb; ["node4"]; 18), Node(2cd21d2debc73eeb9b8bffb7532cb08d176b7c95; ["node5"]; 134)], 
    Main.HllGraph.Edge[])

As you can see we have 5 nodes and no edges because we didn’t make them yet.
As depicted, we currently have 5 nodes without any edges as they have not been created yet. Next, let us proceed to transfer the established nodes to RediSearch.

    HllGraph.set_node(conn, node1, "b")
    HllGraph.set_node(conn, node2, "b")
    HllGraph.set_node(conn, node3, "b")
    HllGraph.set_node(conn, node4, "b")
    HllGraph.set_node(conn, node5, "b")

Here is a snapshot from RedisInsight displaying these nodes. It is important to note that they are not included in the RediSearch index as it has not been created yet.

![alt text](<Pics/Screenshot from 2024-07-22 23-41-10.png>)

HllGraph fully supports all HllSet set operations. Let's demonstrate by creating a Union of two nodes, node1 and node2. Below is the code to achieve this:

    union_node = HllGraph.union_nodes(conn, node1, node2, ["union"], "b")

HllGraph offers two variations for each set_node and set_edge operation: one that generates only the resulting node and necessary edges linking it to the node-arguments, and another that not only performs the first task but also generates a hash in Redis. The latter version of set functions includes an extra parameter for establishing a connection to Redis (referred to as ‘conn’ in union_nodes(conn, node1, node2, . . .).

Upon completion of this operation, there will be two edges in the list of hashes (refer to hashes with the prefix ‘b:e:. . . . .’):

![alt text](<Pics/Screenshot from 2024-07-23 00-08-12.png>)

Now, let's proceed with creating a RediSearch index to store the created nodes. To begin, we will define the schema for this index:

    try
        Redis.execute_command(conn, ["FT.CREATE", "nodes", "ON", "HASH", 
    "PREFIX", 1, "b:n:", 	# Here is the prefix that we used in node hashes
            "SCHEMA", "sha1", "TEXT", "labels", "TEXT", "search", # We skipped dataset field
            "VECTOR", 
            "HNSW", 
            "16", 
            "TYPE", 
            "FLOAT32", 	# Notice we are using Float32 instead of UInt64
            "DIM", 
            "1024", 	# The size search vector the same as HllSet
            "DISTANCE_METRIC", 
            "COSINE",
            "INITIAL_CAP", 
            "50000", 
            "M", 
            "40", 
            "EF_CONSTRUCTION", 
            "100", 
            "EF_RUNTIME", 
            "20", 
            "EPSILON", 
            "0.8"])
    catch e
        println(e)
    end

We have added comments to certain fields in the schema to provide clarification. One change we made was switching from UInt64 to FLOAT32 in HllSet. This adjustment was necessary to meet the requirements of RediSearch. Although we initially had a precision of 64 bits, we decided to downgrade to 32 bits in order to conserve memory. Unfortunately, RediSearch does not support 16 bit floats, so further reduction was not possible. Below is the index for the b:nodes:

![alt text](<Pics/Screenshot from 2024-07-23 00-29-43.png>)

Executing a basic search query will retrieve all nodes:

    ft.search nodes * return 2 sha1 labels
    
    1) "6"
    2) "b:n:b31793fa8c4efbbbe33c49c25c5d6da577b454a9"
    3) 1) "sha1"
    2) "b31793fa8c4efbbbe33c49c25c5d6da577b454a9"
    3) "labels"
    4) "[\"node1\"]"
    4) "b:n:e14ccb30d22d17466672ec17249b4bee629d0b2e"
    5) 1) "sha1"
    2) "e14ccb30d22d17466672ec17249b4bee629d0b2e"
    3) "labels"
    4) "[\"node3\"]"
    6) "b:n:451d7e0f051d78724b24ae3385dea0af2c13dbc1"
    7) 1) "sha1"
    2) "451d7e0f051d78724b24ae3385dea0af2c13dbc1"
    3) "labels"
    4) "[\"node2\"]"
    8) "b:n:bf0f8f1d599288bf667c0c5a6826597551db7872"
    9) 1) "sha1"
    2) "bf0f8f1d599288bf667c0c5a6826597551db7872"
    3) "labels"
    4) "[\"node5\"]"
    10) "b:n:13ff162d70febd79a8d81a6ce292c8a4d4042489"
    11) 1) "sha1"
    2) "13ff162d70febd79a8d81a6ce292c8a4d4042489"
    3) "labels"
    4) "[\"union\"]"
    12) "b:n:b15f46bc0b09317820635b5193c87b5369bddbc9"
    13) 1) "sha1"
    2) "b15f46bc0b09317820635b5193c87b5369bddbc9"
    3) "labels"
    4) "[\"node4\"]"



## Still unsettled things

### Balancing memory footprint and calculations

The use of Relational Algebra within HllSet offers a vast array of possibilities for creating new HllSets, thereby generating new Graph nodes. The Graph maintains the relationships between node arguments and the resulting node, allowing for the regeneration of the dataset for the resulting node based on the datasets of the argument nodes. One potential solution could be to store the resulting dataset in memory when utilizing the graph and omit it when saving to disk.

### Utilizing Multiple RediSearch Indexes for Nodes, Edges, and Tokens

Maintaining separate indices for each SGS data type—Node, Edge, and Token—presents challenges in querying data. Moreover, RediSearch prohibits using the same hash across multiple indices.

RediSearch links each index to a unique prefix or pattern within the Redis keys. When a hash key aligns with an index's designated pattern, RediSearch automatically incorporates that hash into the index based on its predefined schema. As each hash key is tied to a single full key name, it can correspond to only one index pattern at a time.

Nevertheless, there are strategies to navigate this limitation and enable a hash to be searchable across multiple indices:

1. **Duplicate Data**: Replicating the hash under different keys corresponding to various indices' patterns increases storage demands due to data redundancy.
2. **Alias or Reference Keys**: Establish lightweight keys that reference the original hash and adhere to the indices' patterns. This method introduces additional complexity in managing references and can complicate the processes of data retrieval and updates.
3. **Schema Design**: Carefully plan your index schemas and key naming strategies to accommodate your query needs with minimal indices. This may involve utilizing more sophisticated queries within a single index rather than distributing data across multiple indices.

Alternatively, the `RENAME` command allows for reassigning a hash to a different index by modifying its key to fit an alternate pattern. This operation, which does not replicate the data, is particularly effective in scenarios where data transitions through various states or stages and requires searchability in different contexts. However, it does not support the simultaneous presence of the same hash in more than one index.

## References

https://www.cnbc.com/2022/09/21/why-elon-musk-says-patents-are-for-the-weak.html 


## Appendix

I would like to discuss the core aspects of SGS development strategy regarding Intellectual Properties, drawing insights from notable industry practices [1].

During a tour, when Jay Leno inquired whether SpaceX had patented the material used in constructing its spacecraft, Elon Musk clarified that his company does not focus on patenting. "We don't really patent things," Musk stated. 

He expressed a general disinterest in patents, remarking, "I don’t care about patents. Patents are for the weak."

Musk views patents primarily as obstacles to innovation, suggesting that they are often employed to hinder competition rather than to foster advancement. "Patents are generally used as a blocking technique," he explained, likening them to "landmines in warfare." 

According to Musk, patents do not promote progress; instead, they merely prevent others from pursuing similar paths.

This perspective is consistent with Musk's previous statements. In a 2014 memo to Tesla employees, he attributed the company's potential for success to its ability to attract and motivate top engineering talent, rather than to its portfolio of patents. He criticized the patent system for hampering technological advancement, maintaining the status quo for large corporations, and benefiting the legal field rather than the inventors themselves.

Furthermore, Tesla's legal page contains a commitment that underscores this philosophy: the company promises not to engage in patent litigation against anyone who wishes to use its technology in good faith.

These insights into Musk’s approach to intellectual property highlight a strategic focus on innovation and open access, rather than on securing competitive edges through legal protections.
