module Parse ( Ast (..), Op (..), parse ) where

import Data.Char
import Data.Maybe
import Data.List

import Type
import Tokenize
import Ast
import ParseDecl
import ParseExpr


parse :: [String] -> Ast
parse = fst . parseFile

parseFile :: [String] -> (Ast, [String])
parseFile [] = (File [], [])
parseFile (x:xs) = (addAst file line, final)
    where
        (line, rest) = parseTopLvlLine (x:xs)
        (file, final) = parseFile rest

parseTopLvlLine :: [String] -> (Ast, [String])
parseTopLvlLine (x:xs) =
    case decl of
        (FuncType _ _) -> if (head rest) == ";"
                              then (FunDecl decl name, tail rest)
                              else let block = parseLineOrBlock rest
                                  in (Func decl name (fst block), snd block)
        _              -> if (head rest) == "="
                            then (Init decl name expr, tail exprRest)
                            else if (head rest) == ";"
                                then (VarDecl decl name False, tail rest)
                                else error "Expected ; or ="
    where
        (decl, name, rest) = parseDecl (x:xs)
        (expr, exprRest) = parseExpr $ drop 1 rest
    
parseBlock :: [String] -> (Ast, [String])
parseBlock [] = (Block [], [])
parseBlock (";":xs) = (Block [], xs)
parseBlock ("}":xs) = (Block [], xs)
parseBlock (x:xs) = (addAst (fst block) (fst expr), snd block)
    where
        expr = parseLine (x:xs)
        block = parseBlock $ snd expr

parseLine :: [String] -> (Ast, [String])
parseLine [] = (undefined, [])
parseLine ("if":"(":xs) = parseIf xs
parseLine ("while":"(":xs) = parseWhile xs
parseLine ("return":r)
    | (head r) == ";" = (Return Nothing, tail r)
    | otherwise = (Return $ Just expr, drop 1 r2)
    where
        (expr, r2) = parseExpr r
parseLine (x:xs)
    | isType x = (VarDecl decl name False, if (head rest) == ";" then tail rest else name:rest)
    | otherwise = (fst expr, drop 1 $ snd expr)
        where
            (decl, name, rest) = parseDecl (x:xs)
            expr = parseExpr (x:xs)

isType :: String -> Bool
isType str = elem str typeShortlist

parseIf :: [String] -> (Ast, [String])
parseIf (x:xs) =
    if length (snd block1) > 0 && (snd block1) !! 0 == "else"
        then (If (fst expr) (fst block1) (fst block2), snd block2)
        else (If (fst expr) (fst block1) (Block []), snd block1)
    where
        expr = parseExpr (x:xs)
        block1 = parseLineOrBlock $ drop 1 $ snd expr
        block2 = parseLineOrBlock $ drop 1 $ snd block1

parseWhile :: [String] -> (Ast, [String])
parseWhile (x:xs) = (While (fst cond) (fst block), snd block)
    where
        cond = parseExpr (x:xs)
        block = parseLineOrBlock $ drop 1 $ snd cond

parseLineOrBlock :: [String] -> (Ast, [String])
parseLineOrBlock (";":xs) = (Block [], xs)
parseLineOrBlock ("{":xs) = parseBlock xs
parseLineOrBlock (x:xs) = (Block [fst line], snd line)
    where line = parseLine (x:xs)