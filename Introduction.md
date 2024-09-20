# Introduction into Self Generative Systems (SGS)

>***Things are great and small, not only by the will of fate and circumstances, but also according to the concepts they are built on.*** — Kozma Prutkov [2]

This article begins by exploring the concept of self-reproducing automata, as introduced by John von Neumann (refer to [1]). According to the Wikipedia entry [15], the initial studies on self-reproducing automata date back to 1940. Over the span of more than 80 years, significant advancements have been made in this field of research and development, bringing us closer to the realization of systems capable of self-reproduction, which we will refer to as self-generative systems (SGS).

The purpose of this article is to demonstrate a proof of concept by developing a Metadatum SGS. Metadatum is a metadata management system that leverages Julia and Neo4J Graph DB as its operational environment.

## 0. Introduction to John von Neumann theory of self-reproduction

John von Neumann's concept of self-replicating systems is intriguingly straightforward. Imagine a system composed of three distinct modules: A, B, and C.

![alt text](<Pics/Screenshot from 2024-07-21 08-57-31.png>)

Module A acts as a Universal Constructor, capable of crafting any entity based on a provided blueprint or schema.
 Module B functions as a Universal Copier, able to replicate any entity's detailed blueprint or duplicate an entity instance. 
Module C, the Universal Controller, initiates an endless cycle of self-replication by activating modules A and B.

![alt text](<Pics/Screenshot from 2024-07-21 08-57-51.png>)
Figure 2.

The self-replication process begins with Module C, leading to the creation of an identical system, System 1, from the original System 0. This new system is equally capable of initiating its own self-replication cycle, adhering to the same algorithm.
From this analysis, several key insights emerge.
 Firstly, the self-replication algorithm is sufficiently generic to be implemented across various platforms. 
Secondly, Module C's infinite loop can orchestrate the self-replication process. 
Lastly, this algorithm represents a theoretical framework for system upgrade automation, or self-upgrading.
However, in its basic form, a self-replicating system merely clones itself. To enhance its utility, a fourth module, Module D, is introduced. This module enables interaction with the system’s environment and access to its resources, effectively functioning as an application within an operating system composed of Modules A, B, and C.

![alt text](<Pics/Screenshot from 2024-07-21 08-58-13.png>)

Figure 3.

Additionally, a special unit for storing module descriptions, termed the System Description, is incorporated. This upgraded self-replication process, depicted in subsequent figures, involves creating copies of each module description (A, B, C, D) alongside the System Description unit. This leads to the creation of an upgraded system version, which then replaces the old version, thus achieving a new iteration of the system.

![alt text](<Pics/Screenshot from 2024-07-21 08-58-30.png>)

Figure 4.
This enhanced model differs from John von Neumann's original concept by introducing a dedicated unit for system descriptions, allowing the system to interact with its environment via Module D, and modifying the role of Module B to work solely with the System’s Description.
Despite these advancements, the initial creation of the first self-replicating system remains an unsolved "Chicken and Egg" dilemma. Yet, as we draw parallels between this abstract model and software systems, we see opportunities for applying self-replication in managing software application life cycles.

![alt text](<Pics/Screenshot from 2024-07-21 08-58-49.png>)

Figure 5.
In software terms, Modules A, B, and C could represent engines facilitating continuous service processes, such as database engines, servers, or runtime environments. Module A could serve as a compiler or interpreter, generating processes based on source code. Module B might support reflection, serialization, and data buffering, ensuring system persistence and enabling development, evolution, and backup. Module D would represent application software, facilitating user and environment interaction.
Ultimately, viewing self-generative systems (SGS) as a means to standardize and automate the development cycle of software applications—from development to testing, and testing to production—opens up exciting possibilities for autonomous software development.
The purpose of this document is to utilize the concept of SGS within the Metadata Management System to analyze the Socio-Economic System.

# 1. Introduction to Metadata

Metadata is essentially information about information. It encompasses any type of digital content that can be stored on a computer, including documents, databases, images, videos, audio files, and sensor signals. From a metadata standpoint, all of these forms of data are treated equally and hold the same significance.

![alt text](<Pics/Screenshot from 2024-07-21 08-59-11.png>)

What, then, can be said about the concept of metadata for metadata? Essentially, metadata refers to data about data. Thus, when we discuss metadata derived from metadata, we are essentially discussing the same entity.

This point is crucial. We propose to manage both the metadata of original data and the metadata of metadata through a singular metadata system. This approach is visually represented in the figure, where we depict the metadata loop closing in on itself.

Furthermore, we delineate the ongoing process of generating metadata, which evolves over time both from the initial data and from metadata previously created. This cyclical process highlights the dynamic and iterative nature of metadata generation.

![alt text](<Pics/Screenshot from 2024-07-21 08-59-28.png>)

By integrating socio-economic systems (SES) mapping into statistical information systems (SIS) through statistical observation, and then mapping SIS into Metadata, we can develop a comprehensive and generalized scheme.

![alt text](<Pics/Screenshot from 2024-07-21 08-59-42.png>)

The diagram illustrates the SES   SIS and SIS  (Metadata), clearly demonstrating how it maintains the integrity and structural relationships within the displayed system, as discussed earlier.

It is also the rationale behind our proposal to use SGS as the cornerstone of the Metadata Management System.

This approach not only highlights the crucial characteristic of statistics as a system— its closed nature in relation to the Statistical Information System (SIS)—but also ensures that any data encompassed by or generated within the system throughout its processing phase is seamlessly integrated into the SIS. This integration process is precise, safeguarding the original data's structure.

In the contemporary landscape, statistical information transcends traditional statistical indicators and tables. It leverages an array of computer technologies for presenting statistical data and the outcomes of statistical analyses. This encompasses everything from basic tables and charts to sophisticated multimedia and virtual reality presentations.

When it comes to metadata, it encompasses all forms of data. For these datasets, it's imperative to create descriptive metadata elements and to forge connections among these elements. 

Conceptually, metadata can be visualized as a graph. Within this graph, metadata elements are depicted as nodes, while the links between these elements are represented by the graph's edges. This structure facilitates a comprehensive and interconnected representation of metadata, enhancing the understanding and utilization of statistical information.

But before moving to the graph let’s look at the very short introduction to the HllSets (HyperLogLog Sets). For more information please look at my previous post [3].

# 2. HllSets

In a previous post [4], I introduced HllSets, a data structure based on the HyperLogLog algorithm developed by Philippe Flajolet, Éric Fusy, Olivier Gandouet, and Frédéric Meunier [6]. In that post, we demonstrated that HllSets adhere to all the fundamental properties of Set theory.

The fundamental properties that HllSets complies with are as follows:

Commutative Property:
1. (A ∪ B) = (B ∪ A)
2. (A ∩ B) = (B ∩ A)

Associative Property:
3. (A ∪ B) ∪ C) = (A ∪ (B ∪ C))
4. (A ∩ B) ∩ C) = (A ∩ (B ∩ C))

Distributive Property:
5. ((A ∪ B) ∩ C) = (A ∩ C) ∪ (B ∩ C)
6. ((A ∩ B) ∪ C) = (A ∪ C) ∩ (B ∪ C)

Identity:
7. (A ∪ ∅) = A
8. (A ∩ U) = A

In addition to these fundamental properties, HllSets also satisfy the following additional laws:

Idempotent Laws:
9. (A ∪ A) = A
10. (A ∩ U) = A

To see the source code that proves HllSets satisfies all of these requirements, refer to **lisa.ipynb**[8].

# 3. Mapping HllSets into Graph

The graph can be defined as follows:

G = {V, E}, 
Where

G - graph;
V - is the set of graph nodes, which in our case will represent HllSet;
E - is the set of edges connecting connected nodes of the graph.

Node v  V, can be described as struct in programming languages ​​C++, Rust, Julia or Dict in Python language. In the code snippet below, we have used Julia notation.

    struct Node <: AbstractGraphType
        sha1::String		    # SHA1 hash ID, calculated using subset of metadata
        labels::Vector{String}	# array of labels        
        dataset::Vector{Int}	# dump of HllSet (compact presentation of HllSet)
    end

The edges of the graph describe the connections between nodes. Any pair of nodes can have more than one edge, and each edge has a direction from the source to the target.

    struct Edge <: AbstractGraphType
        source::String # sha1 of the source node
        target::String # sha1 of the target node
        r_type::String # label of the edge
        props::Config  # Additional properties presented as JSON
    end

# 4. Life cycle, Transactions, and Commits

>***If everything past were present, and the present continued to exist with the future, who would be able to make out: where are the causes and where are the consequences?*** — Kozma Prutkov [2]

This section will delve into some key technical details that are crucial for developing SGS as a programming system.

## 4.1. Transactions

In this section, we employ the "transaction" index (or a transactional table - t_table, if we're discussing databases) as an alternative to the System Description found in the self-reproduction diagram of Chapter 0 (refer to Figure 5). The following is a flowchart that outlines the process of handling external data in the Metadatum SGS.

![alt text](<Pics/Screenshot from 2024-07-21 09-00-06.png>)

Figure 5.

Module D obtains inputs from the System Environment and records these inputs by generating records in the "transaction" index. Simultaneously, Module A, with assistance from Module B (the copier), retrieves these references from the "transaction" index. It then processes these references by engaging the appropriate processors and subsequently uploads the processed data back into the System.

It is crucial to note that SGS never directly sends incoming data to the System. Instead, it first segregates all incoming data logically into a staging area using the references in the "transaction" index.

This approach helps us achieve several objectives:
1. Clear separation between data already present in the System and new data.
2. Complete control over the processing of new data, enabling us to track completed tasks and pending work. It also facilitates support for parallel processing and recovery from failures.
3. Ability to isolate unsupported data types.
4. Strict adherence to the self-reproduction flow outlined in Chapter 0.

## 4.2. Commits

In the SGS (Self Generative System), each entity instance is categorized under one of three primary commit statuses, which are crucial for tracking modifications. These statuses are as follows:

1. Head: This status signifies that the entity instance represents the most recent modification.
2. Tail: An instance with this status is identified as a prior modification, indicating that it is not the latest version.
3. Deleted: This status is assigned to instances that have been marked as removed from the system.

To better understand how commit statuses function, consider the following illustration. The diagrams visualize the timeline of modifications, starting from the most recent (current time) at the top and progressing downwards to the earliest at the bottom.

Current time.

![alt text](<Pics/Screenshot from 2024-07-21 09-00-24.png>)

Time of the previous commit. Take note of how the updated version of item_2 changed the commit state in row 2 from its original state.

![alt text](<Pics/Screenshot from 2024-07-21 09-00-41.png>)

Time of the initial commit.

![alt text](<Pics/Screenshot from 2024-07-21 09-01-00.png>)

Essentially, each commit in the system carries its unique "commit forest," depicted through a distinct matrix. For every commit, there's a designated matrix. However, there's no cause for concern—these matrices are virtual. They don't need to exist physically as we can generate them as needed.

At time = 1, we observed three items: item_1, item_2, and item_4, all of which were tagged with the 'head' status, indicating their current and active state.

By time = 2, changes were made to item_2. Consequently, at this juncture, a new version of item_2 emerged within the SGS, introducing a fresh element. This new version was also tagged with the 'head' status, while the previous version's status was switched to 'tail,' indicating it's now a historical entry.

Updating is a methodical process that entails several steps:

- Creating a new version of the item to be updated;
- Applying the required modifications to this new version;
- Saving these changes;
- Establishing a connection between the new and the former version of the item.

By time = 3, two additional elements—item_5 and item_6—were introduced and similarly tagged with the 'head' status.

This mechanism of commits in the SGS crafts a narrative of system evolution. Each cycle of self-reproduction within the SGS adds new chapters to this "history book," linking back to system snapshots at the time of each commit.

In this "history book," we distinguish between 'head' and 'tail.' The 'head' represents the immediate memory and the current state of the SGS, while the 'tail' serves as an archive. Although still accessible, retrieving information from the 'tail' requires additional steps.

The commit history functions as the intrinsic timeline of Self-Generative Systems, akin to biological time in living organisms.

## 4.3. Static and Dynamic Metadata Structure

Data serves as a mirror of the real world, while metadata, as an abstraction of the data, serves as a reflection of the real world.

![alt text](<Pics/Screenshot from 2024-07-21 09-01-19.png>)

These observations rest on the underlying belief that there is a direct correspondence between the complexities of the real world and the elements within our datasets. Here, each piece of data is essentially a combination of a value and its associated attributes. When we define associative relationships based on data and its metadata, drawing on similarities between data elements, we're dealing with what's known as a **Static Data Structure**. The term "static" implies that these relationships are fixed; they remain constant and can be replicated as long as the data elements are described using the same attributes. Modern databases excel at mapping out these types of relationships.

Nonetheless, **the primary aim of data analysis is to unearth hidden connections among data elements, thereby uncovering analogous relationships in the real world**. This endeavor presupposes that the relationships we discover within our data somehow mirror those in the real world. However, these connections are not immediately apparent—they are hidden and transient, emerging under specific conditions. As circumstances evolve, so too do the relationships among real-world elements, necessitating updates in our Data Structure to accurately reflect these changes. This leads us to the concept of a Dynamic Data Structure.

A **Dynamic Data Structure** emerges from the process of data analysis, facilitated by various analytical models, including Machine Learning or Artificial Intelligence. Broadly speaking, an analytical model comprises an algorithm, source data, and the resulting data. The relationships forged by these models are ephemeral and might not have real-world counterparts. Often, they represent an analyst's subjective interpretation of the real world's intricacies. These model-generated relationships constitute a **Dynamic Data Structure**.

The nature of a Dynamic Data Structure is inherently fluid—relationships deemed accurate yesterday may no longer hold today. Different models will vary in their relevance, and the analyst's primary challenge is to select the models that best fit the current real-world scenario and the specific aspects under consideration.

## SGS AI Architecture

The diagram below illustrates the advanced architecture of Self-Generative Systems (SGS) with an integrated Large Language Model (LLM). This representation highlights a seamless and non-intrusive method of integrating AI models, particularly LLMs, into the SGS framework, functioning in a plug-and-play manner. Notably, both the Metadata Models (MM) and the Large Language Models (LLM) receive inputs from a shared tokenization process. This commonality ensures that both components process the same foundational data, facilitating efficient and coherent system performance. This integration exemplifies how modern AI components can be effectively incorporated into broader systems to enhance functionality and adaptability.

![alt text](<Pics/Screenshot from 2024-09-10 19-53-29.png>)

The diagram presented below illustrates the natural symbiosis between Metadata Models (MM) and Large Language Models (LLM), showcasing how they complement each other effectively within a system. As observed, MM operates on acquired data and primarily leverages analytical tools and techniques, including the application of high-level set operations (HllSet). These models are inherently more grounded, focusing on realistic, pragmatic outcomes derived from concrete data insights.

In contrast, LLMs, like other AI models, depend on the synthesis of new ideas by tapping into their deep understanding of the relationships between elements within their domain. These models are characterized by their creativity and idealism, often producing innovative yet sometimes unrealistic outputs or even prone to generating hallucinatory results.

As highlighted in the diagram, MM serves a critical role in balancing the creative exuberance of LLMs. By applying reasonable constraints, MM can harness and refine the imaginative outputs of LLMs, grounding them in practicality. This interplay ensures that the strengths of both models are utilized to their fullest, combining creativity with realism to produce robust, reliable, and useful results. This symbiotic relationship not only enhances the functionality of each model but also significantly improves the overall efficacy of the system in which they are integrated. 

![alt text](<Pics/Screenshot from 2024-09-10 20-30-21.png>)

MM: Looking at the Differences. HyperLogLog Hashing (HllSets). MM Universe: Analytical by Nature, built on HllSet operations.

The MM universe is fundamentally analytical in nature, relying on a structured approach to understanding and manipulating data. Metadata models serve as explicit constraints that guide the generation process. Through HllSet operations, which utilize HyperLogLog hashing, MM provides a framework for efficiently summarizing large datasets while maintaining accuracy in the representation of cardinality (the number of distinct elements).

HllSets allow for quick computations of probabilistic cardinalities, enabling the MM universe to analyze differences among datasets. This analytical lens emphasizes the importance of understanding the nuances and variations in data, which can be crucial for tasks such as data deduplication, anomaly detection, and clustering. The constraints imposed by metadata models ensure that the generative processes remain focused and relevant, allowing for the creation of outputs that are coherent and contextually appropriate.


LLM: Looking for Commonalities. Attention is all you need. LLM Universe: Synthetical by Nature, built on compositional generations.

The LLM universe is synthetical by nature, focusing on the identification of commonalities rather than differences. Grounded in the principles of attention mechanisms, LLMs leverage vast amounts of textual data to generate human-like text through compositional generation. This approach enables LLMs to synthesize information from diverse sources, creating coherent narratives or responses based on patterns learned during training.

While MM emphasizes analytical differentiation, LLM seeks to establish connections and similarities across datasets. This synthesis is driven by the model’s ability to attend to various parts of the input data, allowing it to weave together disparate pieces of information into a unified output. However, this compositional generation process is not without its challenges; it requires careful calibration to ensure that the generated content remains relevant and meaningful.


# Summary

The document discusses the concept of Self-Generative Systems (SGS), inspired by John von Neumann's theory of self-reproducing automata, and applies it to a Metadata Management System utilizing HyperLogLog Sets (HllSets) and graph databases to manage data and its metadata efficiently. It explores the structure and functions of self-replicating systems, which consist of modules for construction, copying, controlling, and interacting with the environment, along with a system description unit for storing module descriptions. The article outlines the implementation of these concepts through a proof of concept for a Metadatum SGS, which leverages Julia and Neo4J for metadata management.

The discussion includes the introduction of HllSets, which comply with set theory properties, and their mapping into a graph database structure, where nodes represent HllSets and edges represent connections between these sets. It delves into technical aspects like transactions, commits, and the handling of data in a self-generative manner, emphasizing the importance of commit statuses (Head, Tail, Deleted) in tracking modifications and maintaining the system's integrity.

Furthermore, the text distinguishes between static and dynamic metadata structures, highlighting the dynamic nature of data relationships and the role of analytical models in uncovering these relationships. A demonstration using data from the Enron Email Analysis project illustrates the practical application of these concepts, showcasing the process of ingesting, processing, and committing data to simulate the day-to-day operation of the Metadatum SGS.

Overall, the article presents a comprehensive exploration of self-replicating systems and their application to metadata management, offering insights into the potential of these systems to revolutionize how we handle and analyze data in various domains.


# References
1. https://archive.org/details/theoryofselfrepr00vonn_0/page/74/mode/2up
2. https://en.wikipedia.org/wiki/Kozma_Prutkov
3. https://www.linkedin.com/posts/alex-mylnikov-5b037620_hllset-relational-algebra-activity-7199801896079945728-4_bI?utm_source=share&utm_medium=member_desktop
4. https://www.linkedin.com/posts/alex-mylnikov-5b037620_hyperloglog-based-approximation-for-very-activity-7191569868381380608-CocQ?utm_source=share&utm_medium=member_desktop
5. https://www.linkedin.com/posts/alex-mylnikov-5b037620_hllset-analytics-activity-7191854234538061825-z_ep?utm_source=share&utm_medium=member_desktop
6. https://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf
7. https://static.googleusercontent.com/media/research.google.com/en//pubs/archive/40671.pdf
8. https://github.com/alexmy21/lisa_meta/blob/main/lisa.ipynb
9. https://www.linkedin.com/posts/alex-mylnikov-5b037620_demo-application-enron-email-analysis-with-activity-7195832040548614145-5Ot5?utm_source=share&utm_medium=member_desktop
10. https://github.com/alexmy21/lisa_meta/blob/main/lisa_enron.ipynb
11. https://github.com/alexmy21/lisa_meta/blob/main/hll_algebra.ipynb
12. https://arxiv.org/pdf/2311.00537 (Machine Learning Without a Processor: Emergent Learning in a Nonlinear Electronic Metamaterial)
13. https://s3.amazonaws.com/arena-attachments/736945/19af465bc3fcf3c8d5249713cd586b28.pdf (Deep listening)
14. https://www.deeplistening.rpi.edu/deep-listening/
15. https://en.wikipedia.org/wiki/Von_Neumann_universal_constructorhttps://en.wikipedia.org/wiki/Markov_property
 
