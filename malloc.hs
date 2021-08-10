||============================================
|| DATA STRUCTURE - BLOCKS, HEAP, MEMORY

|| The data type can be any of the following:
|| -> Empty - indicates a cell which has not yet been written to
|| -> Live - boolean value indicating liveness, True if live, False if free
|| -> Pointer - an address of a cell in the heap
|| -> Size - size of the block or heap (in 'cells')
|| -> Data - generic data type

|| An entry of any of these types corresponds to a fixed data size and this is the most
|| granular division. From this is follows that each of these entries is allocated the same number of bits.
|| This could be very inefficient if the max block size is very large.
|| Here for the purposes of simulation, the absolute value this size corresponds to is of lesser importance.
|| Let's assume here that the heap size does not exceed 255 bytes, and so each cell has the size of 1 byte.
|| If the heap size were to be larger, the cell size would also have to increase to allow for the Size cells to hold larger block sizes.
|| But these issues are somewhat below the level of abstraction this simulation works on.

data ::= Empty | Live bool | Pointer num | Size num | Mark bool | Data

heap_type == [data] || heap is a list of data cells
data_block_type == [data] || another type synonym
memory == (heap_type, data, data, data) || memory is a tuple - the heap, the heap size, the free list pointer, and the mark bit indicating is a mark scan has been completed yet
                                        || (used to stop endless recursion when garbage collection needs to be invoked)
                                        || every element except for the heap could be treated as a register


|| Initial memory state - for simplicity, the starting point is a heap with no data, where all space
|| is a single free block, instead of being completely empty.
mem_start :: memory
||mem_start = (Live False : Mark False : Size 197 : [Empty|x<-[1..197]], Size 200, Pointer 0, Mark False)

|| Alternative starting memory - for testing and demonstration of the program
 mem_start = ([Live True,Mark False,Size 20,Data,Data,Data,Data,Data,Data,Pointer 26,Data,Data,Data,Data,Data,Data,Pointer 129,Data,Data,Data,Data,Data,Data,Live True,
             Mark False,Size 5,Data,Pointer 129,Data,Data,Data,Live True,Mark False,Size 30,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 6,Data,Data,Data,Data,Data,Data,Live True,Mark
             False,Size 50,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 40,Data,
             Data,Data,Data,Data,Data,Data,Pointer 3,Data,Data,Data,Pointer 26,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,Mark False,Size 12,Pointer 184,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,
             Mark False,Size 13,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty],Size 200,Pointer 169,Mark False)


|| Some functions for demonstration of the functionality
demonstrate1 = malloc mem_start [Data|x<-[1..10]]   || writes the data without invoking GC
demonstrate2 = malloc mem_start [Data|x<-[1..30]]   || triggers GC and then writes the data
demonstrate3 = malloc mem_start [Data|x<-[1..100]]  || returns an out of memory error as GC cannot free up enough memory



||============================================
|| AUXILLIARY FUNCTIONS

|| get heap function (these functions retrieve a specific element of memory)
gh :: memory -> heap_type
gh (heap, heap_size, flp, mark) = heap

|| get FLP function
gflp :: memory -> data
gflp (heap, heap_size, flp, mark) = flp

|| get size function
gs :: memory -> data
gs (heap, (Size heap_size), flp, mark) = Size heap_size

|| Since malloc returns a tuple including the updated memory and the last write address, to allocate another block to memory returned by malloc we need to extract the memory from the tuple
gm :: (memory,data) -> memory
gm (mem, return_addr) = mem

|| E.G.
demonstrate4 = malloc mem_start [Data|x<-[1..10]]
demonstrate5 = malloc (gm demonstrate4) [Data|x<-[1..20]]

|| convert Pointer num or Size num to num
|| '-1' return value is used across the helper functions in the program to indicate unexpected/erroneous values
|| - the parent functions (i.e. the caller functions) intercept and handle these return values accordingly
to_num :: data -> num
to_num (Size s) = s
to_num (Pointer p) = p
to_num any = -1

|| Function for writing into the heap
write :: heap_type -> data_block_type -> data -> heap_type
write heap d_block (Pointer p) = (take p heap) ++ d_block ++ (drop (# d_block + p) heap)

|| find and xfind are used to traverse the list to find a specific entry - specific pointer
find :: ([*],*) -> num
find (mylist, item) = (# mylist) - from_xfind, if from_xfind >= 0
                    = (-1), otherwise
                      where
                      from_xfind = (xfind (mylist, item, # mylist))

xfind :: ([*],*,num) -> num
xfind (front : rest, item, 1) = (-1)
xfind (item : rest, item, index) = index
xfind (front : rest, item, index) = xfind (rest, item, index-1)

|| find_back searches for a specific element starting from the end of the list
find_back :: ([*],*) -> num
find_back (mylist, item) = xfind_back (mylist, item, (# mylist)-1)

xfind_back :: ([*], *, num) -> num
xfind_back (mylist, item, (-1))   = error "find_back: item not found"
xfind_back (mylist, item, index)  = index, if (mylist ! index) = item
                                  = xfind_back (mylist, item, index-1), otherwise

||============================================
|| MEMORY ALLOCATOR

|| Main malloc function, takes memory as argument and returns a tuple consisting of the updated memory and the starting address to which the data was written
malloc :: memory -> [data] -> (memory,data)
malloc (heap,Size hs,Pointer flp, Mark markbit) d_block

                  = error "malloc: block larger than heap size", if min_size > hs || safety check
                  = error "malloc: can't input an empty block", if (# d_block = 0) || safety check
                  || run garbage collector on the heap and then attempt memory allocation on the updated heap
                  = malloc (mark_scan (heap, Size hs, Pointer flp, Mark markbit) roots) d_block, if write_addr = Pointer (-1) || write_addr will be a (-1) pointer if the findfree function couldn't find a suitable block
                  = ((updated_heap, Size hs, updated_flp, Mark False), write_addr), otherwise || if none of the above checks triggered, continue with allocation
                    where
                    updated_heap =  (write temp_heap ([Live True, Mark False, Size (# d_block)] ++ d_block) header_addr), if free_block_size - min_size < 4 || write data to the target block - case of perfect fit (i.e. not splitting)
                                 =  (write temp_heap ([Live True, Mark False, Size (# d_block)] ++ d_block
                                    ++ [Live False, Mark False, Size (free_block_size-(# d_block)-3)]) header_addr), otherwise || analogous, but where splitting is required / possible
                    min_size = 3 + max[1, # d_block] || minimum free block size
                    write_addr  = findfree heap (Pointer flp) (# d_block) || find a suitable free block and its first address
                    header_addr = Pointer (to_num(write_addr)-3) || and the corresponding header address
                    free_block_size = to_num(heap ! (to_num(write_addr)-1))
                    || restructuring the free list when a new data block is written
                    (temp_heap, updated_flp)  = update_list_f (heap, Pointer flp) header_addr, if free_block_size - min_size < 4 || case of perfect fit
                                              = update_list_p (heap, Pointer flp) header_addr second_addr, otherwise || case where splitting is required
                                                where
                                                second_addr = Pointer(to_num(header_addr) + (# d_block) + 3)

|| Used for finding a free block of sufficient size
|| the allocation policy is first-fit: best-fit would be very slow, and next-fit requires keeping track of an additional pointer
findfree :: heap_type -> data -> num -> data

findfree heap (Pointer p) block_size
                    || returns Pointer (-1) to indicate the whole list has been searched and there is no free block of sufficient size
                    = (Pointer (-1)), if (to_num(heap ! (p+2))) < min_size & to_num(heap ! (p+3)) = (-1)
                    = (Pointer (p+3)), if (to_num(heap ! (p+2))) >= min_size || returns current Pointer if the size of the block is sufficient
                    = findfree heap (heap ! (p+3)) block_size, otherwise || continues searching the free list otherwise
                      where
                      min_size = 3 + max[1, block_size]


|| Two functions for restructuring the free list when new data is written - update_list_f for full fit (i.e. where the chosen block isn't big enough split)

update_list_f :: (heap_type,data) -> data -> (heap_type,data)
update_list_f (heap, Pointer flp) (Pointer flp)   = (heap, (heap ! (flp+3)))
update_list_f (heap, Pointer flp) (Pointer p)     = ((write heap [heap ! (p+3)] (Pointer index)), Pointer flp) || copies the pointer value to the previous free-list pointer cell
                                                    where
                                                    index = find (heap, (Pointer p))
update_list_f mem othercell                       = error "update_list_f: non-pointer cell passed as argument" || safety case in case a non-pointer data cell was passed to the function

|| And update_list_p for partial fit (i.e. where the chosen block is big enough to split)

update_list_p :: (heap_type,data) -> data -> data -> (heap_type,data)
update_list_p (heap, Pointer flp) (Pointer flp) (Pointer p2)  = ((write heap [heap ! (flp+3)] (Pointer (p2+3))), Pointer p2)
update_list_p (heap, Pointer flp) (Pointer p1) (Pointer p2)   = ((write heap_temp [Pointer p2] (Pointer index)), Pointer flp) || similar mechanism as above but since we're also creating a new block
                                                                where                                                         || the copying needs to happen in two stages
                                                                index = find (heap, (Pointer p1))
                                                                heap_temp = write heap [heap ! (p1+3)] (Pointer (p2+3))
update_list_p mem othercell1 othercell2                       = error "update_list_p: non-pointer cell passed as argument" || safety case as above


||============================================
|| GARBAGE COLLECTOR


|| Root pointers - this specific set corresponds to the sample heap as provided above
roots = [Pointer 3, Pointer 26]


|| Mark_scan function binds the mark and scan functions together
mark_scan :: memory -> [data] -> memory
mark_scan (heap,hs,flp,Mark True)  roots =  error "out of memory - mark_scan inititated for the second time" || raise error is mark_scan initiated for the second time
mark_scan (heap,hs,flp,Mark False) roots =  memscan (marked_mem)
                                            where
                                            marked_mem = (mark heap roots, hs, flp, Mark False)


|| Mark function takes the heap and the root pointers and calls xmark for each of these pointers
mark :: heap_type -> [data] -> heap_type
mark heap []             = heap
mark heap (front : rest) = mark (xmark heap front) rest

|| xmark function takes the heap and a Pointer to the start of the data block
xmark :: heap_type -> data -> heap_type
xmark heap (Pointer p) = mark curr_heap children_block, if heap ! (p-2) = (Mark False) || if the block not marked yet, call mark on the curr_heap and pass it the children of the given block as roots
                       = heap, otherwise || if the block already marked, return unchanged heap
                         where
                         curr_heap = write heap [Mark True] (Pointer (p-2)) || curr_heap is the heap after updating the mark bit to True
                         children_block = children (take (to_num (heap ! (p-1)) + 3) (drop (p-3) heap)) || find all pointers in the given block

|| function for children of a given pointer - i.e. relevant pointers in a given data block
children :: [data] -> [data]
children []                   = [] || base case
children ((Pointer p) : rest) = [Pointer p] ++ children rest || if the front element is a Pointer add it to the result
children (othertype : rest)   = children rest || otherwise continue

|| Scan function - runs xscan passing it the memory and the Pointer to the first data cell in the heap
memscan :: memory -> memory
memscan mem = xscan mem (Pointer 3)

|| Xscan function - scans through all the blocks and free them is the mark bit is False
xscan :: memory -> data -> memory
xscan (heap, Size s, Pointer flp, markbit) (Pointer p)
                      || call xscan recursively with the updated heap and flp and a Pointer to the next block if Pointer still within the range of the heap size
                    = xscan (curr_heap, Size s, curr_flp, markbit) (Pointer ( 3 + p + (to_num(heap ! (p-1))))), if p < s
                    = (heap, Size s, Pointer flp, Mark True), otherwise || return the input memory if pointer exceeds heap size
                      where
                      || updating the heap
                      (curr_heap, hs, curr_flp, curr_mb) = ((write heap [Mark False] (Pointer (p-2)), Size s, Pointer flp, markbit)), if heap ! (p-2) = (Mark True) || if mark bit of the block is True, change it to False and continue
                                                = free (heap, Size s, Pointer flp, markbit) (Pointer (p-3)), otherwise || otherwise, free the block




|| free function - takes memory and a Pointer to the start of the target block and returns updated memory
|| the ordering policy is AO - this improves the virtual memory performance by clustering live blocks at the lower end of the heap
free :: memory -> data -> memory
free (heap, hs, Pointer flp, markbit) (Pointer p)
                  = (heap, hs, Pointer flp, markbit), if heap ! p = (Live False) || returns unchanged memory if the target block is already free
                  = start_list, if p < flp || adding to the beginning of the free-list
                  = middle_list, if next_free >= p || adding anywhere in the middle of the free-list
                  = end_list, otherwise || adding to the end of the free-list
                    where
                    next_free = (find (drop p heap, (Live False))) + p || find the address of the next free block
                    index = find (heap, (Pointer next_free)) || find returns (-1) is item wasn't found on the list
                    start_list =  ((write heap [Live False, Mark False, (heap ! (p+2)), Pointer flp] (Pointer p)), hs, Pointer p, markbit) || updates heap in 2 stages
                    middle_list = ((write temp_heap [Pointer p] (Pointer (index))),hs,Pointer flp,markbit)
                                  where
                                  temp_heap = write heap [Live False, Mark False, (heap ! (p+2)), Pointer next_free] (Pointer p)
                    end_list =    ((write temp_heap [Pointer p] (Pointer (previous_free+3))), hs, Pointer flp,markbit) || updates heap in 2 stages
                                  where
                                  previous_free = find_back (heap, (Live False)) || findind the last free block on the list
                                  temp_heap = write heap [Live False, Mark False, (heap ! (p+2))] (Pointer p)
