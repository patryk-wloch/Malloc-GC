# Malloc-GC

This repo contains a work from a project aiming to use pure functional languages to create a simulator of a **Free-List** ([Wiki](https://en.wikipedia.org/wiki/Free_list)) **Memory Allocator** algorithm, otherwise known as **Malloc** ([Wiki](https://en.wikipedia.org/wiki/Memory_management#DYNAMIC)). 

The simulation mimics how low-level languages, such as C, manage memory at application runtime ([Wiki](https://en.wikipedia.org/wiki/C_dynamic_memory_allocation)), but operates on a certain level of abstraction. For example, in the simulator:
* Data is generic and composed of fixed-size cells called simply **Data**
* Pointers to specific locations are recorded as decimal - instead of hexadecimal - values (*e.g. Pointer n can be interpreted as the n-th byte from the start of the heap*)

The implementation was originally in **Miranda** ([Wiki](https://en.wikipedia.org/wiki/Miranda_(programming_language))), a now-niche pure functional language, and a protoplast of **Haskell**. The repo contains both the initial version in Miranda, and a subsequent adaptation in Haskell. 

Example (from the Haskell version):
1. Below is a sample possible state of a 200-byte heap, as well as some extra cells including the size of the heap and the pointer to the first free block - it contains some generic data cells, indicators of liveness of different blocks, and some pointers.
```haskell
mem_start :: Memory
mem_start =  ([ Live True,Mark False,Size 20,Data,Data,Data,Data,Data,Data,Pointer 26,Data,
                Data,Data,Data,Data,Data,Pointer 129,Data,Data,Data,Data,Data,Data,Live True,
                Mark False,Size 5,Data,Pointer 129,Data,Data,Data,Live True,Mark False,Size 30,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Live True,Mark False,Size 6,Data,Data,Data,Data,Data,Data,Live True,Mark False,
                Size 50,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 40,Data,Data,Data,
                Data,Data,Data,Data,Pointer 3,Data,Data,Data,Pointer 26,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
                Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,Mark False,Size 12,
                Pointer 184,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,
                Mark False,Size 13,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,
                Empty,Empty,Empty ],

                Size 200,Pointer 169,Mark False)
```
2. We call the main (malloc) function, requesting it to allocate space for a 10-byte data block.<br>&nbsp;<br>
<img width="342" alt="image" src="https://user-images.githubusercontent.com/73844047/129214881-32e72812-d1e8-4ee3-98e2-d4d7ca11fe34.png">
3. The new block has been annotated and the updated memory returned. An additional return value is a Pointer to where the new block was written (here, it's Pointer 187)<br>&nbsp;<br>
<img width="563" alt="image" src="https://user-images.githubusercontent.com/73844047/129215356-aff1f2d8-0f2c-4310-91d6-fac4983d9eec.png">



