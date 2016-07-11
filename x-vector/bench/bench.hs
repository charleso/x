{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE ScopedTypeVariables #-}

import           Criterion.Main
import           Criterion.Types

import qualified Data.List as List
import qualified Data.Map as Map
import           Data.String (String)

import           P

import           System.IO (IO)

import qualified X.Data.Vector as Boxed
import qualified X.Data.Vector.Generic as Generic
import qualified X.Data.Vector.Unboxed as Unboxed
import qualified X.Data.Vector.Stream  as Stream


main :: IO ()
main =
    defaultMainWith config
     [ bgroup "Transpose" allTranspose
     , bgroup "Merge" allMerge
     ]
 where
  allTranspose = invertMap $
   concatMap transposeBenchmarks [1000,2000,3000,4000,5000,6000,7000,8000,9000,10000]

  allMerge = invertMap $
   concatMap mergeBenchmarks $ fmap (*10) [1000,2000,3000,4000,5000,6000,7000,8000,9000,10000]

  invertMap =
   fmap (uncurry bgroup) .
   Map.toList .
   Map.fromListWith (flip mappend) .
   fmap (second (:[]))


config :: Config
config =
  defaultConfig {
      reportFile = Just "dist/build/x-vector-bench.html"
    , csvFile = Just "dist/build/x-vector-bench.csv"
    }

transposeBenchmarks :: Int -> [(String, Benchmark)]
transposeBenchmarks size =
  withMatrix size $ \list vec ->
    [ ("Data.List.transpose/list", bench (renderSize size) $ nf List.transpose list)
    , ("X.Data.Vector.Generic.transpose/vector", bench (renderSize size) $ nf Generic.transpose vec)
    ] <>
    -- Going to list and back takes forever, so we only include it in smaller benchmarks --
    if size <= 2000 then
      [("Data.List.transpose/vector", bench (renderSize size) $ nf vecListTranspose vec)]
    else
      []

mergeBenchmarks :: Int -> [(String, Benchmark)]
mergeBenchmarks size =
  withPairs size $ \list1 list2 vec1 vec2 ->
    [ ("list", bench (renderSize size) $ nf3 Stream.mergeList fun list1 list2)
    , ("vector", bench (renderSize size) $ nf3 Generic.merge fun vec1 vec2)
    , ("vector-convert-list", bench (renderSize size) $ nf3 (\f a b -> Unboxed.fromList $ Stream.mergeList f (Unboxed.toList a) (Unboxed.toList b)) fun vec1 vec2)
    ]
 where
  fun = Stream.mergePullOrd id
  nf3 f x y z = nf (f x y) z


renderSize :: Int -> String
renderSize n =
  show n <> "²"

vecListTranspose :: Boxed.Vector (Unboxed.Vector Int) -> Boxed.Vector (Unboxed.Vector Int)
vecListTranspose =
  Boxed.fromList .
  fmap Unboxed.fromList .
  List.transpose .
  fmap Unboxed.toList .
  Boxed.toList

withMatrix :: Int -> ([[Int]] -> Boxed.Vector (Unboxed.Vector Int) -> a) -> a
withMatrix size f =
  let
    list :: [[Int]]
    list = List.replicate size [0..size]

    vec :: Boxed.Vector (Unboxed.Vector Int)
    vec = fmap Unboxed.fromList $ Boxed.fromList list
  in
    list `deepseq` vec `deepseq` f list vec

withPairs :: Int -> ([Int] -> [Int] -> Unboxed.Vector Int -> Unboxed.Vector Int -> a) -> a
withPairs size f =
  let
    list1 :: [Int]
    list1 = [0..size]
    list2 = List.take size $ List.drop (size `div` 2) $ List.cycle list1

    vec1 = Unboxed.fromList $ list1
    vec2 = Unboxed.fromList $ list2
  in
    list1 `deepseq` list2 `deepseq` vec1 `deepseq` vec2 `deepseq` f list1 list2 vec1 vec2
