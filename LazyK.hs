module Main
(main,
 parse
) where

import Data.Array
import Data.Char
import Data.List
import System.Exit
import System(getArgs)

-- Really, every Comb should just be a function Comb -> Comb.
-- However, we need to be able to extract an Int from a church numeral,
-- so we need Nat.
data Comb = Func (Comb -> Comb)
          | Nat Int

-- Function application on a combinator - should it be more lazy?
ap :: Comb -> Comb -> Comb
ap (Func c1) = c1
($$) = ap
getNat :: Comb -> Int
getNat (Nat n) = n

---- Implementation of the combinators
i :: Comb
i = Func id
k :: Comb
k = Func (\x -> Func (\_ -> x))
s :: Comb
s = Func (\x -> Func (\y -> Func (\z -> (x $$ z) $$ (y $$ z))))
-- The hacky bullshit combinator - used to extract useful numbers from church numerals
inc :: Comb
inc = Func (\(Nat n) -> Nat (n+1))

---- Useful functions for constructing and destructing combinators
car :: Comb -> Comb
car e = e $$ k
cdr :: Comb -> Comb
cdr e = e $$ (k $$ i)
cons :: Comb -> Comb -> Comb
cons x xs = s $$ (s $$ i $$ (k $$ x)) $$ (k $$ xs)

churchIncrement :: Comb -> Comb
churchIncrement c = s $$ (s $$ (k $$ s) $$ k) $$ c
fromChurchNumeral :: Comb -> Int
fromChurchNumeral c = getNat $ c $$ inc $$ Nat 0


churchNumerals :: [Comb]
churchNumerals = iterate churchIncrement (k $$ i)

churchNumeralTable :: Array Int Comb
churchNumeralTable = array (0, 256) $ zip [0..256] churchNumerals

getChurchNumeral :: Int -> Comb
getChurchNumeral n | n < 0 || n > 256 = getChurchNumeral 256
getChurchNumeral n = churchNumeralTable ! n

-- what should nil be??
encodeList :: [Comb] -> Comb
encodeList = foldr cons i
decodeList :: Comb -> [Comb]
decodeList c = car c : decodeList (cdr c)

---- The core of the interpreter. The bits that drive the computation.

transformInput :: String -> Comb
transformInput l = encodeList $ map (getChurchNumeral . ord) l ++ repeat (getChurchNumeral 256)
transformOutput :: Comb -> [Int]
transformOutput = map fromChurchNumeral . decodeList

-- output a character or exit if necessary
outputCharacter :: Int -> IO ()
outputCharacter 256 = exitSuccess
outputCharacter n | n > 256 = exitWith $ ExitFailure (n-256)
outputCharacter n = putChar (chr n)

-- runComb is what drives everything
runComb :: Comb -> IO ()
runComb c = do
  input <- getContents
  let c' = c $$ transformInput input
  mapM_ outputCharacter $ transformOutput c'

---- An expression language with a conventional representation and a parser for it.
data Expr = S | K | I | App Expr Expr
          deriving Show

exprToComb :: Expr -> Comb
exprToComb S = s
exprToComb K = k
exprToComb I = i
exprToComb (App e1 e2) = exprToComb e1 $$ exprToComb e2

parseExp :: String -> (Expr, String)
parseExp ('I':rest) = (I, rest)
parseExp ('i':rest) = (I, rest)
parseExp ('K':rest) = (K, rest)
parseExp ('k':rest) = (K, rest)
parseExp ('S':rest) = (S, rest)
parseExp ('s':rest) = (S, rest)
parseExp ('`':rest) =
  let (e1, rest') = parseExp rest
      (e2, rest'') = parseExp rest'
  in (App e1 e2, rest'')
parseExp ('(':rest) = parse' True rest
parseExp (')':_) = error "paren fuckup"
parseExp (c:rest) | isSpace c = parseExp rest
parseExp s = error $ "other fuckup: '" ++ s ++ "'"

-- collecteAdjacent nested string
collectAdjacent :: Bool -> String -> ([Expr], String)
collectAdjacent True (')':rest) = ([], rest)
collectAdjacent False (')':_) = error "unmatched closed paren"
collectAdjacent False [] = ([], [])
collectAdjacent True [] = error "unexpected EOF"
collectAdjacent nested string =
  let (exp, rest) = parseExp string
      (exps, rest') = collectAdjacent nested rest
  in (exp:exps, rest')

parse' :: Bool -> String -> (Expr, String)
parse' False [] = (I, []) -- stupid special case
parse' nested string =
  let (exps, rest) = collectAdjacent nested string
  in (foldl1 App exps, rest)

-- Strip out whitespace and comment lines
stripNonsense :: String -> String
stripNonsense = filter (not . isSpace) . unlines . filter (not . isPrefixOf "#") . lines

parse :: String -> Expr
parse = fst . parse' False . stripNonsense

-- Utilities for running programs.

runString :: String -> IO ()
runString = runComb . exprToComb . parse

runFile :: String -> IO ()
runFile sourcePath = readFile sourcePath >>= runString

main :: IO ()
main = do
  [sourcePath] <- getArgs
  runFile sourcePath