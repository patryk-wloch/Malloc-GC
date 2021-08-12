
data Data_ = Empty | Live Bool | Pointer Int | Size Int | Mark Bool | Data deriving (Eq, Show)

type HeapType = [Data_]
type DataBlockType = [Data_]
type Memory = (HeapType, Data_, Data_, Data_)

mem_start :: Memory
mem_start =  ([Live True,Mark False,Size 20,Data,Data,Data,Data,Data,Data,Pointer 26,Data,Data,Data,Data,Data,Data,Pointer 129,Data,Data,Data,Data,Data,Data,Live True,
             Mark False,Size 5,Data,Pointer 129,Data,Data,Data,Live True,Mark False,Size 30,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 6,Data,Data,Data,Data,Data,Data,Live True,Mark
             False,Size 50,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live True,Mark False,Size 40,Data,
             Data,Data,Data,Data,Data,Data,Pointer 3,Data,Data,Data,Pointer 26,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,
             Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,Mark False,Size 12,Pointer 184,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Data,Live False,
             Mark False,Size 13,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty,Empty],Size 200,Pointer 169,Mark False)

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
-- demonstrate2 = malloc mem_start [Data|x<-[1..30]]   --  triggers GC and then writes the data
-- demonstrate3 = malloc mem_start [Data|x<-[1..100]]  --  returns an out of memory error as GC cannot free up enough memory
-- demonstrate4 = malloc mem_start [Data|x<-[1..10]]
-- demonstrate5 = malloc (gm demonstrate4) [Data|x<-[1..20]]

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

-- Main malloc function, takes memory as argument and returns a tuple consisting of the updated memory and the starting address to which the data was written
malloc :: Memory -> [Data_] -> (Memory,Data_)
malloc (heap, Size hs, Pointer flp, Mark markbit) d_block

    | min_size > hs               = error "malloc: block larger than heap size" -- safety check
    | length d_block == 0         = error "malloc: can't input an empty block" -- safety check
    -- run garbage collector on the heap and then attempt memory allocation on the updated heap
    -- write_addr will be a (-1) pointer if the findfree function couldn't find a suitable block
    -- | write_addr == Pointer (-1)  = malloc (mark_scan (heap, Size hs, Pointer flp, Mark markbit) roots) d_block
    --  if none of the above checks triggered, continue with allocation
    | otherwise                   = ((updated_heap, Size hs, updated_flp, Mark False), write_addr)

    where
    updated_heap
        | free_block_size - min_size < 4  = (write temp_heap ([Live True, Mark False, Size (length d_block)] ++ d_block) header_addr) --  write data to the target block - case of perfect fit (i.e. not splitting)
        | otherwise                       = (write temp_heap ([Live True, Mark False, Size (length d_block)] ++ d_block
                                            ++ [Live False, Mark False, Size (free_block_size-(length d_block)-3)]) header_addr) --  analogous, but where splitting is required / possible
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
-- the allocation policy is first-fit: best-fit would be very slow, and next-fit requires keeping track of an additional pointer
findfree :: HeapType -> Data_ -> Int -> Data_

findfree heap (Pointer p) block_size
                    -- returns Pointer (-1) to indicate the whole list has been searched and there is no free block of sufficient size
      | (to_num(heap !! (p+2))) < min_size && to_num(heap !! (p+3)) == (-1)   = (Pointer (-1))
      | (to_num(heap !! (p+2))) >= min_size                                   = (Pointer (p+3))  -- returns current Pointer if the size of the block is sufficient
      | otherwise                                                             = findfree heap (heap !! (p+3)) block_size -- continues searching the free list otherwise
      where
      min_size = 3 + maximum[1, block_size]


-- Two functions for restructuring the free list when new data is written - update_list_f for full fit (i.e. where the chosen block isn't big enough split)

update_list_f :: (HeapType, Data_) -> Data_ -> (HeapType, Data_)
update_list_f (heap, Pointer flp) (Pointer p)
    | p == flp    = (heap, (heap !! (flp+3)))
    | otherwise   = ((write heap [heap !! (p+3)] (Pointer index)), Pointer flp) -- copies the pointer value to the previous free-list pointer cell
                    where
                    index = find (heap, (Pointer p))
update_list_f mem othercell = error "update_list_f: non-pointer cell passed as argument" -- safety case in case a non-pointer data cell was passed to the function

-- And update_list_p for partial fit (i.e. where the chosen block is big enough to split)

update_list_p :: (HeapType, Data_) -> Data_ -> Data_ -> (HeapType, Data_)
update_list_p (heap, Pointer flp) (Pointer p1) (Pointer p2)
    | flp == p1   = ((write heap [heap !! (flp+3)] (Pointer (p2+3))), Pointer p2)
    | otherwise   = ((write heap_temp [Pointer p2] (Pointer index)), Pointer flp) -- similar mechanism as above but since we're also creating a new block
                    where                                                         -- the copying needs to happen in two stages
                    index = find (heap, (Pointer p1))
                    heap_temp = write heap [heap !! (p1+3)] (Pointer (p2+3))
update_list_p mem othercell1 othercell2 = error "update_list_p: non-pointer cell passed as argument" -- safety case as above
