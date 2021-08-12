-- ===========================================
-- DATA STRUCTURE - BLOCKS, HEAP, MEMORY
-- The data type can be any of the following:

-- -> Empty - indicates a cell which has not yet been written to
-- -> Live - boolean value indicating liveness, True if live, False if free
-- -> Pointer - an address of a cell in the heap
-- -> Size - size of the block or heap (in 'cells')
-- -> Data - generic data type

-- An entry of any of these types corresponds to a fixed data size and this is the most
-- granular division. From this is follows that each of these entries is allocated the same number of bits.
-- This could be very inefficient if the max block size is very large.
-- Here for the purposes of simulation, the absolute value this size corresponds to is of lesser importance.
-- Let's assume here that the heap size does not exceed 255 bytes, and so each cell has the size of 1 byte.
-- If the heap size were to be larger, the cell size would also have to increase to allow for the Size cells to hold larger block sizes.
-- But these issues are somewhat below the level of abstraction this simulation works on.


data Data_ = Empty | Live Bool | Pointer Int | Size Int | Mark Bool | Data deriving (Eq, Show)

type HeapType = [Data_]
type DataBlockType = [Data_]
type Memory = (HeapType, Data_, Data_, Data_)

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

-- ============================================
-- AUXILLIARY FUNCTIONS

-- get heap function (these functions retrieve a specific element of memory)
gh :: Memory -> HeapType
gh (heap, heap_size, flp, mark) = heap

-- get FLP function
gflp :: Memory -> Data_
gflp (heap, heap_size, flp, mark) = flp

-- get size function
gs :: Memory -> Data_
gs (heap, (Size heap_size), flp, mark) = Size heap_size

-- Since malloc returns a tuple including the updated memory and the last write address,
-- to allocate another block to memory returned by malloc we need to extract the memory from the tuple
gm :: (Memory, Data_) -> Memory
gm (mem, return_addr) = mem

--  E.G.
demonstrate1 = malloc mem_start [Data|x<-[1..10]]   -- writes the data without invoking GC
demonstrate2 = malloc mem_start [Data|x<-[1..30]]   --  triggers GC and then writes the data
demonstrate3 = malloc mem_start [Data|x<-[1..100]]  --  returns an out of memory error as GC cannot free up enough memory
demonstrate4 = malloc mem_start [Data|x<-[1..10]]

-- convert Pointer num or Size num to num
-- '-1' return value is used across the helper functions in the program to indicate unexpected/erroneous values
-- - the parent functions (i.e. the caller functions) intercept and handle these return values accordingly
to_num :: Data_ -> Int
to_num (Size s) = s
to_num (Pointer p) = p
to_num any = -1

-- Function for writing into the heap
write :: HeapType -> DataBlockType -> Data_ -> HeapType
write heap d_block (Pointer p) = (take p heap) ++ d_block ++ (drop (length d_block + p) heap)

-- find and xfind are used to traverse the list to find a specific entry - specific pointer
find :: Eq a => ([a],a) -> Int
find (mylist, item) = if from_xfind >= 0
                      then (length mylist) - from_xfind
                      else (-1)
                      where
                      from_xfind = (xfind (mylist, item, length mylist))

xfind :: Eq a => ([a],a,Int) -> Int
xfind (front : rest, item, 1) = (-1)
xfind (front : rest, item, index)
    | front == item = index
    | otherwise     = xfind (rest, item, index-1)

-- find_back searches for a specific element starting from the end of the list
find_back :: Eq a => ([a],a) -> Int
find_back (mylist, item) = xfind_back (mylist, item, (length mylist)-1)

xfind_back :: Eq a => ([a], a, Int) -> Int
xfind_back (mylist, item, (-1))   = error "find_back: item not found"
xfind_back (mylist, item, index)  = if (mylist !! index) == item
                                    then index
                                    else xfind_back (mylist, item, index-1)



-- ============================================
-- MEMORY ALLOCATOR

-- Main malloc function, takes memory as argument and returns a tuple consisting of the
-- updated memory and the starting address to which the data was written
malloc :: Memory -> [Data_] -> (Memory,Data_)
malloc (heap, Size hs, Pointer flp, Mark markbit) d_block

    | min_size > hs               = error "malloc: block larger than heap size" -- safety check
    | length d_block == 0         = error "malloc: can't input an empty block" -- safety check
    -- run garbage collector on the heap and then attempt memory allocation on the updated heap
    -- write_addr will be a (-1) pointer if the findfree function couldn't find a suitable block
    | write_addr == Pointer (-1)  = malloc (mark_scan (heap, Size hs, Pointer flp, Mark markbit) roots) d_block
    --  if none of the above checks triggered, continue with allocation
    | otherwise                   = ((updated_heap, Size hs, updated_flp, Mark False), write_addr)

    where
    updated_heap
                                          --  write data to the target block - case of perfect fit (i.e. not splitting)
        | free_block_size - min_size < 4  = (write temp_heap ([Live True, Mark False, Size (length d_block)] ++ d_block) header_addr)
                                          --  analogous, but where splitting is required / possible
        | otherwise                       = (write temp_heap ([Live True, Mark False, Size (length d_block)] ++ d_block
                                            ++ [Live False, Mark False, Size (free_block_size-(length d_block)-3)]) header_addr)

    min_size = 3 + maximum[1, length d_block] -- minimum free block size
    write_addr  = findfree heap (Pointer flp) (length d_block) -- find a suitable free block and its first address
    header_addr = Pointer (to_num(write_addr)-3) -- and the corresponding header address
    free_block_size = to_num(heap !! (to_num(write_addr)-1))

    -- restructuring the free list when a new data block is written
    (temp_heap, updated_flp)
        | free_block_size - min_size < 4  = update_list_f (heap, Pointer flp) header_addr -- case of perfect fit
        | otherwise                       = update_list_p (heap, Pointer flp) header_addr second_addr -- case where splitting is required
                                            where
                                            second_addr = Pointer(to_num(header_addr) + (length d_block) + 3)

-- Used for finding a free block of sufficient size
-- the allocation policy is first-fit: best-fit would be very slow, and next-fit
-- requires keeping track of an additional pointer
findfree :: HeapType -> Data_ -> Int -> Data_

findfree heap (Pointer p) block_size
      -- returns Pointer (-1) to indicate the whole list has been searched and there is no free block of sufficient size
      | (to_num(heap !! (p+2))) < min_size && to_num(heap !! (p+3)) == (-1)   = (Pointer (-1))
      -- returns current Pointer if the size of the block is sufficient
      | (to_num(heap !! (p+2))) >= min_size                                   = (Pointer (p+3))
      -- continues searching the free list otherwise
      | otherwise                                                             = findfree heap (heap !! (p+3)) block_size
      where
      min_size = 3 + maximum[1, block_size]


-- Two functions for restructuring the free list when new data is written -
-- update_list_f for full fit (i.e. where the chosen block isn't big enough split)

update_list_f :: (HeapType, Data_) -> Data_ -> (HeapType, Data_)
update_list_f (heap, Pointer flp) (Pointer p)
    | p == flp    = (heap, (heap !! (flp+3)))
    -- copies the pointer value to the previous free-list pointer cell
    | otherwise   = ((write heap [heap !! (p+3)] (Pointer index)), Pointer flp)
                    where
                    index = find (heap, (Pointer p))

-- safety case in case a non-pointer data cell was passed to the function
update_list_f mem othercell = error "update_list_f: non-pointer cell passed as argument"

-- And update_list_p for partial fit (i.e. where the chosen block is big enough to split)

update_list_p :: (HeapType, Data_) -> Data_ -> Data_ -> (HeapType, Data_)
update_list_p (heap, Pointer flp) (Pointer p1) (Pointer p2)
    | flp == p1   = ((write heap [heap !! (flp+3)] (Pointer (p2+3))), Pointer p2)
    -- similar mechanism as above but since we're also creating a new block the copying needs to happen in two stages
    | otherwise   = ((write heap_temp [Pointer p2] (Pointer index)), Pointer flp)
                    where
                    index = find (heap, (Pointer p1))
                    heap_temp = write heap [heap !! (p1+3)] (Pointer (p2+3))

-- safety case as above
update_list_p mem othercell1 othercell2 = error "update_list_p: non-pointer cell passed as argument"

-- ============================================
-- GARBAGE COLLECTOR


-- Root pointers - this specific set corresponds to the sample heap as provided above
roots = [Pointer 3, Pointer 26]


-- Mark_scan function binds the mark and scan functions together
mark_scan :: Memory -> [Data_] -> Memory
-- raise error is mark_scan initiated for the second time
mark_scan (heap, hs, flp, Mark True)  roots =   error "out of memory - mark_scan inititated for the second time"
mark_scan (heap, hs, flp, Mark False) roots =   memscan (marked_mem)
                                                where
                                                marked_mem = (mark heap roots, hs, flp, Mark False)


-- Mark function takes the heap and the root pointers and calls xmark for each of these pointers
mark :: HeapType -> [Data_] -> HeapType
mark heap []             = heap
mark heap (front : rest) = mark (xmark heap front) rest

-- xmark function takes the heap and a Pointer to the start of the data block
xmark :: HeapType -> Data_ -> HeapType
xmark heap (Pointer p)
    -- if the block not marked yet, call mark on the curr_heap and pass it the children of the given block as roots
    | heap !! (p-2) == (Mark False) = mark curr_heap children_block
    -- if the block already marked, return unchanged heap
    | otherwise                     = heap
                                      where
                                      -- curr_heap is the heap after updating the mark bit to True
                                      curr_heap = write heap [Mark True] (Pointer (p-2))
                                      -- find all pointers in the given block
                                      children_block = children (take (to_num (heap !! (p-1)) + 3) (drop (p-3) heap))

--  function for children of a given pointer - i.e. relevant pointers in a given data block
children :: [Data_] -> [Data_]
-- base case
children []                   = []
--  if the front element is a Pointer add it to the result
children ((Pointer p) : rest) = [Pointer p] ++ children rest
-- otherwise continue
children (othertype : rest)   = children rest

--  Scan function - runs xscan passing it the memory and the Pointer to the first data cell in the heap
memscan :: Memory -> Memory
memscan mem = xscan mem (Pointer 3)

-- Xscan function - scans through all the blocks and free them is the mark bit is False
xscan :: Memory -> Data_ -> Memory
xscan (heap, Size s, Pointer flp, markbit) (Pointer p)
    -- call xscan recursively with the updated heap and flp and a Pointer to the next block if Pointer still within the range of the heap size
    | p < s           = xscan (curr_heap, Size s, curr_flp, markbit) (Pointer ( 3 + p + (to_num(heap !! (p-1)))))
    -- return the input memory if pointer exceeds heap size
    | otherwise       = (heap, Size s, Pointer flp, Mark True)
                        where
                        -- updating the heap
                        (curr_heap, hs, curr_flp, curr_mb)
                            -- if mark bit of the block is True, change it to False and continue
                            | heap !! (p-2) == (Mark True)  = ((write heap [Mark False] (Pointer (p-2)), Size s, Pointer flp, markbit))
                            -- otherwise, free the block
                            | otherwise                     = free (heap, Size s, Pointer flp, markbit) (Pointer (p-3))




-- free function - takes memory and a Pointer to the start of the target block and returns updated memory
-- the ordering policy is AO - this improves the virtual memory performance by clustering live blocks at the lower end of the heap
free :: Memory -> Data_ -> Memory
free (heap, hs, Pointer flp, markbit) (Pointer p)
    -- returns unchanged memory if the target block is already free
    | heap !! p == (Live False)   = (heap, hs, Pointer flp, markbit)
    -- adding to the beginning of the free-list
    | p < flp                     = start_list
    --  adding anywhere in the middle of the free-list
    | next_free >= p              = middle_list
    -- adding to the end of the free-list
    | otherwise                   = end_list
    where
    -- find the address of the next free block
    next_free = (find (drop p heap, (Live False))) + p
    -- find returns (-1) is item wasn't found on the list
    index = find (heap, (Pointer next_free))
    --  updates heap in 2 stages
    start_list = ((write heap [Live False, Mark False, (heap !! (p+2)), Pointer flp] (Pointer p)), hs, Pointer p, markbit)
    middle_list = ((write temp_heap [Pointer p] (Pointer (index))),hs,Pointer flp,markbit)
                  where
                  temp_heap = write heap [Live False, Mark False, (heap !! (p+2)), Pointer next_free] (Pointer p)
    end_list =    ((write temp_heap [Pointer p] (Pointer (previous_free+3))), hs, Pointer flp,markbit) -- updates heap in 2 stages
                  where
                  previous_free = find_back (heap, (Live False)) -- finding the last free block on the list
                  temp_heap = write heap [Live False, Mark False, (heap !! (p+2))] (Pointer p)
