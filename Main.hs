import Data.Char
import Control.Monad
import Shuffle
import Card

data Column = Column {
              concealed :: [Card],
              visible ::   [Card]
              }

data Game = Game 
         [[Card]]  -- foundations
         [Column]  -- columns
         [Card]    -- deck
         [Card]    -- reserves

instance Show Game where
    show (Game fg cg dg rg) = 
          let emptySpace = "__"
              hiddenCard = "??"
              noCard =     "  "

              flines = unwords $ map (\f -> if null f then emptySpace else show $ head f) fg
              clines = unwords $ map (\f -> if null $ concealed f then emptySpace else hiddenCard) cg

              vlines = toVisibleLines $ map (reverse.visible) cg where
                   toVisibleLines [[],[],[],[],[],[],[]] = []
                   toVisibleLines vg =
                         unwords (map (\f -> if null f then noCard else show $ head f) vg) 
                       : toVisibleLines (map (\f -> if null f then [] else tail f) vg)

              dlines = unwords [ if null rg then emptySpace else hiddenCard, 
                               if null dg then emptySpace else show $ head dg ]

              lines' = flines:clines:vlines ++ [dlines]
          in unlines lines'

gameOver :: Game -> Bool
gameOver (Game _ cg dg rg) =    
                   all null (map visible cg)
                && all null (map concealed cg)
                && null dg
                && null rg


---------------------------------------------------------
-- The following routines operate on one part 
-- (columns or foundations or deck or reserves ) 
-- of a game.
---------------------------------------------------------

-- Utility functions
goesOnColumn :: Card -> Column -> Bool
goesOnColumn card (Column [] []) = rank card == King
goesOnColumn card (Column _ (vh:_)) = 
    (cardColor card /= cardColor vh) && fromEnum (rank card) + 1 == fromEnum (rank vh)

goesOnFoundation :: Card -> [Card] -> Bool
goesOnFoundation card [] = rank card == Ace 
goesOnFoundation card (fh:_) =
    (suit card == suit fh) && fromEnum (rank card) == fromEnum (rank fh) + 1

-- if the visible portion of a column is empty
-- then "replenish" it with one card from the concealed
-- portion of the column
replenishColumn :: Column -> Column
replenishColumn (Column (ch:ct)  []) = Column ct [ch]
replenishColumn column = column

-- check for empty column has already been done; assert ??
removeOneFromColumn :: [Column] -> Int -> ([Column], Card)
removeOneFromColumn cg index0 =
    let (Column concealed0 visible0) = cg !! index0
        newColumn0 = Column concealed0 (tail visible0)
        newColumn1 = replenishColumn newColumn0
        newColumns0 = take index0 cg ++ newColumn1 : drop (index0+1) cg
    in (newColumns0, head visible0)

-- check for empty column has already been done; assert ??
removeAllFromColumn :: [Column] -> Int -> ([Column], [Card])
removeAllFromColumn cg index0 =
    let (Column concealed0 visible0) = cg !! index0
        newColumn0 = Column concealed0 []
        newColumn1 = replenishColumn newColumn0
        newColumns0 = take index0 cg ++ newColumn1 : drop (index0+1) cg
    in (newColumns0, visible0)

addToFoundations :: [[Card]] -> Int -> Card -> [[Card]]
addToFoundations fg index1 card =
    let foundation1 = fg !! index1
        newFoundation = card : foundation1
    in take index1 fg ++ newFoundation : drop (index1+1) fg

addToColumns :: [Column] -> Int -> [Card] -> [Column]
addToColumns cg index1 cards =
    let (Column concealed1 visible1) = cg !! index1
        newColumn = Column concealed1 (cards ++ visible1)
    in take index1 cg ++ newColumn : drop (index1+1) cg

addOneToColumns :: [Column] -> Int -> Card -> [Column]
addOneToColumns cg index1 card =
    let (Column concealed1 visible1) = cg !! index1
        newColumn = Column concealed1 (card : visible1)
    in take index1 cg ++ newColumn : drop (index1+1) cg

---------------------------------------------------------
-- The following routines operate on an entire game.
---------------------------------------------------------

-- deal a deck of cards out to the klondike layout
start :: Game -> Game
start (Game fg cg dg rg) = 
            let (columns', reserves') = deal cg rg
            in Game fg columns' dg reserves'
            where 
                -- stop dealing out cards when all stacks full
                deal columns'@[] reserves' = (columns', reserves')

                deal columns' reserves' = 
                    let 
                        -- one card up on first stack
                        visibleHead = head reserves' : visible (head columns')

                        -- no concealed cards on first stack (unchanged)
                        concealedHead = concealed $ head columns'

                        -- no cards up after first stack (unchanged)
                        visibleTail = map visible $ tail columns'

                        -- add concealed card to every stack past first
                        concealedTail = zipWith (:) (tail reserves') $ map concealed (tail columns') 

                        -- combine concealed and visible to get column
                        columnsHead = Column concealedHead visibleHead

                        -- zip concealed & visible to get columns'
                        columnsTail = zipWith Column concealedTail visibleTail

                        -- remove used cards from reserves'
                        remainingDeck = drop (length columns') reserves'

                        -- recurse to deal onto remaining columns'
                        (columns'', reserves'') = deal columnsTail remainingDeck

                    in (columnsHead : columns'', reserves'')

fromColumnToFoundation :: Game -> Int -> Int -> Game
fromColumnToFoundation (Game fg cg dg rg) index0 index1 =
    let (newColumns0,removedCard) = removeOneFromColumn cg index0
        newFoundations = addToFoundations fg index1 removedCard
    in Game newFoundations  newColumns0 dg rg 

fromColumnToColumn :: Game -> Int -> Int -> Game
fromColumnToColumn (Game fg cg dg rg) index0 index1 =
    let (newColumns0,removedCards) = removeAllFromColumn cg index0
        newColumns1 = addToColumns newColumns0 index1 removedCards
    in Game fg  newColumns1 dg rg 

fromDeckToColumn :: Game -> Int -> Game
fromDeckToColumn (Game fg cg dg rg) index1 =
    let newDeck = tail dg
        removedCard = head dg
        newColumns = addOneToColumns cg index1 removedCard
    in  Game fg newColumns newDeck rg

fromDeckToFoundation :: Game -> Int -> Game
fromDeckToFoundation (Game fg cg dg rg) index1 =
    let newDeck = tail dg
        removedCard = head dg
        newFoundations = addToFoundations fg index1 removedCard
    in Game newFoundations  cg newDeck rg

fromReservesToDeck:: Game -> Game
fromReservesToDeck (Game fg cg dg rg) = 
    Game fg cg (reverse (take 3 rg) ++ dg) (drop 3 rg)

fromDeckToReserves :: Game -> Game
fromDeckToReserves (Game fg cg dg _) = 
    Game fg cg [] (reverse dg)

-------------------------------------------------------------
-- The following routines do semantic checking and then
-- carry out a command.  By semantic checking I mean: make 
-- sure the command makes sense given the current game state.
-------------------------------------------------------------

-- Helper function
printAndReturn :: Game -> IO Game
printAndReturn game = do
    print game
    return game


playColumnToFoundation :: Game -> Int -> Int -> IO Game
playColumnToFoundation game@(Game fg cg _ _) index0 index1 
                | null.visible $ cg !! index0 = do
                    putStrLn $ "Can not move cards from empty column: " ++ show (index0+1)
                    return game

                | not $ (head.visible $ cg !! index0) `goesOnFoundation` (fg !! index1) = do
                    putStrLn $ "Can not move card from column: " ++ show (index0+1) ++ " to foundation: " ++ [chr (ord 'A' + index1)]
                    return game
                  
                | otherwise = printAndReturn $ fromColumnToFoundation game index0 index1

playColumnToColumn :: Game -> Int -> Int -> IO Game
playColumnToColumn game@(Game _ cg _ _) index0 index1 
                | index0 == index1 = do
                    putStrLn "Can not move cards from a column to itself."
                    return game

                | null.visible $ cg !! index0 = do
                    putStrLn $ "Can not move cards from empty column: " ++ show (index0+1)
                    return game

                | not $ (last.visible $ cg !! index0) `goesOnColumn` (cg !! index1) = do
                    putStrLn $ "Can not move cards from column: " ++ show (index0+1) ++ " to column: " ++ show (index1+1)
                    return game
                  
                | otherwise = printAndReturn $ fromColumnToColumn game index0 index1

playDeckToColumn :: Game -> Int -> IO Game
playDeckToColumn game@(Game _ cg dg _) index1 
                | null dg = do
                    putStrLn "Can not play from empty deck." 
                    return game

                | not $ head dg `goesOnColumn` (cg !! index1) = do
                    putStrLn $ "Can not move cards from deck to column: " ++ show (index1+1)
                    return game
                  
                | otherwise = printAndReturn $ fromDeckToColumn game index1 

playDeckToFoundation :: Game -> Int -> IO Game
playDeckToFoundation game@(Game fg _ dg _) index1 
                | null dg = do
                    putStrLn "Can not play from empty deck." 
                    return game

                | not $ head dg `goesOnFoundation` (fg !! index1) = do
                    putStrLn $ "Can not move cards from deck to foundation: " ++ [chr (ord 'A' + index1)]
                    return game
                  
                | otherwise = printAndReturn $ fromDeckToFoundation game index1 

playFromTable :: Game -> Char -> Char -> IO Game
playFromTable game@(Game _ _ _ _) cmd0 cmd1 
          | cmd1 >= '1' && cmd1 <= '7' = 
              playColumnToColumn game (ord cmd0 - ord '1') (ord cmd1 - ord '1') 
          | cmd1 >= 'A' && cmd1 <= 'D' = 
              playColumnToFoundation game (ord cmd0 - ord '1') (ord cmd1 - ord 'A') 
          | otherwise = do
              putStrLn "Invalid command." 
              return game
  
playFromDeck :: Game -> Char -> IO Game
playFromDeck game@(Game _ _ _ _) cmd1 
          | cmd1 >= '1' && cmd1 <= '7' =
              playDeckToColumn game (ord cmd1 - ord '1') 
          | cmd1 >= 'A' && cmd1 <= 'D' = 
              playDeckToFoundation game (ord cmd1 - ord 'A') 
          | otherwise = do
              putStrLn "Invalid command." 
              return game

updateGame :: Game -> String -> IO Game
updateGame game@(Game _ _ _ rg)  command
        | cmd0 == 'D' = if null rg then do 
                            putStrLn "No cards are available to Draw from.  Use 'R' to replenish."
                            return game
                        else 
                            printAndReturn $ fromReservesToDeck game

        | cmd0 == 'R' = if not (null rg) then do 
                            putStrLn "Can not Replenish reserves while it still contains cards."
                            return game
                        else 
                            printAndReturn $ fromDeckToReserves game

        | cmd0 == 'P' = playFromDeck game cmd1

        | cmd0 >= '1' && cmd0 <= '7' = playFromTable game cmd0 cmd1

        | otherwise = do putStrLn $ "Invalid command: " ++ command
                         return game

        where cmd0 = head command
              cmd1 = if length command > 1 then head $ tail command else ' '

updateLoop :: Game -> IO ()
updateLoop game = 
    Control.Monad.unless (gameOver game) $ do
        command <- getLine
        updatedGame <- updateGame game command
        updateLoop updatedGame

main :: IO ()
main = do 
          shuffledDeck <- shuffle [ Card r s | r<-[Ace .. King], s<-[Hearts .. Clubs]] 

          let
              foundations' = replicate 4 []
              columns' =     replicate 7 $ Column [] []
              deck' =       []
              game = Game foundations' columns' deck' shuffledDeck
              gameInPlay = start game

          print gameInPlay
          updateLoop gameInPlay
          putStrLn "Game Over"

