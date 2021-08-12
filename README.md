# Malloc-GC

## Outline 
This repo contains a work from a project aiming to use pure functional languages to create a simulator of a **Free-List** ([Wiki](https://en.wikipedia.org/wiki/Free_list)) **Memory Allocator** algorithm, otherwise known as **Malloc** ([Wiki](https://en.wikipedia.org/wiki/Memory_management#DYNAMIC)). 

The simulation mimics how low-level languages, such as C, manage memory at application runtime ([Wiki](https://en.wikipedia.org/wiki/C_dynamic_memory_allocation)), but operates on a certain level of abstraction. For example, in the simulator:
* Data is generic and composed of fixed-size cells called simply **Data**
* Pointers to specific locations are recorded as decimal - instead of hexadecimal - values (*e.g. Pointer n can be interpreted as the n-th byte from the start of the heap*)

The implementation was originally in **Miranda** ([Wiki](https://en.wikipedia.org/wiki/Miranda_(programming_language))), a now-niche pure functional language, and a protoplast of **Haskell**. The repo contains both the initial version in Miranda, and a subsequent adaptation in Haskell. 

## Examples (from the Haskell version):

### Simple memory allocation

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
2. We call the main (malloc) function, requesting it to allocate space for a 10-byte data block.
```haskell
malloc mem_start [Data|x<-[1..10]]
```

3. The memory allocation was straightforward, as there was a sufficiently large free block in the free-list The new block has been allocated and the updated memory returned. An additional return value is a Pointer to where the new block was written (here, it's Pointer 187)
```haskell
(([ Live True,Mark False,Size 20,Data,Data,Data,Data,Data,Data,Pointer 26,
    Data,Data,Data,Data,Data,Data,Pointer 129,Data,Data,Data,Data,Data,Data,
    Live True,Mark False,Size 5,Data,Pointer 129,Data,Data,Data,Live True,
    Mark False,Size 30,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Live True,Mark False,Size 6,Data,Data,Data,Data,
    Data,Data,Live True,Mark False,Size 50,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,
    Mark False,Size 40,Data,Data,Data,Data,Data,Data,Data,Pointer 3,Data,Data,
    Data,Pointer 26,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Live False,Mark False,Size 12,Empty,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Live True,Mark False,Size 10,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Empty,Empty,Empty  ],

    Size 200,Pointer 169,Mark False),Pointer 187)
```
### Allocation with garbage collection

1. Using the same sample 200-byte heap as above, we call the malloc function requesting it to allocate space for a 30-byte data block.
```haskell
malloc mem_start [Data|x<-[1..30]]
```
2. There is no sufficiently large free block currently in the heap - that triggers garbage collection to free up unused memory.

3. All blocks which had nothing pointing towards them (i.e. were not in use anymore) were marked as *Live False* by the garbage collector, and the memory allocator then used some of the freed up space to allocate the requested 30-byte block.
```haskell
(([ Live True,Mark False,Size 20,Data,Data,Data,Data,Data,Data,Pointer 26,Data,Data,Data,
    Data,Data,Data,Pointer 129,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 5,
    Data,Pointer 129,Data,Data,Data,Live False,Mark False,Size 30,Pointer 64,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Live False,Mark False,Size 6,Pointer 106,Data,
    Data,Data,Data,Data,Live True,Mark False,Size 30,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Live False,Mark False,Size 17,Pointer 169,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 40,Data,
    Data,Data,Data,Data,Data,Data,Pointer 3,Data,Data,Data,Pointer 26,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Live False,Mark False,Size 12,Pointer 184,Data,Data,Data,Data,Data,
    Data,Data,Data,Data,Data,Data,Live False,Mark False,Size 13,Empty,Empty,Empty,Empty,Empty,
    Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty  ],

    Size 200,Pointer 31,Mark False),Pointer 76)
 ```
