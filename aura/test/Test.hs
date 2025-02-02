{-# LANGUAGE OverloadedStrings #-}

module Main ( main ) where

import           Aura.Languages
import           Aura.Packages.Repository
import           Aura.Pacman
import           Aura.Pkgbuild.Security
import           Aura.Types
import           BasePrelude
import qualified Data.ByteString.Lazy.Char8 as BL
import qualified Data.Map.Strict as M
import qualified Data.Text as T
import qualified Data.Text.IO as T
import           Data.Versions
-- import           Language.Bash.Pretty (prettyText)
import           System.Path
import           Test.Tasty
import           Test.Tasty.HUnit
import           Text.Megaparsec
-- import           Text.Pretty.Simple (pPrintNoColor)

---

main :: IO ()
main = do
  conf <- T.readFile "test/pacman.conf"
  pkb  <- Pkgbuild <$> BL.readFile "test/aura.PKGBUILD"
  defaultMain $ suite conf pkb

suite :: T.Text -> Pkgbuild -> TestTree
suite conf pb = testGroup "Unit Tests"
  [ testGroup "Aura.Core"
    [ testCase "parseDep - python2" $ parseDep "python2" @?= Just (Dep "python2" Anything)
    , testCase "parseDep - python2-lxml>=3.1.0" $ do
        let pn = "python2-lxml>=3.1.0"
            p = parseDep pn
        p @?= Just (Dep "python2-lxml" . AtLeast . Ideal $ SemVer 3 1 0 [] [])
        fmap renderedDep p @?= Just pn
    , testCase "parseDep - foobar>1.2.3" $ do
        let pn = "foobar>1.2.3"
            p = parseDep pn
        p @?= Just (Dep "foobar" . MoreThan . Ideal $ SemVer 1 2 3 [] [])
        fmap renderedDep p @?= Just pn
    , testCase "parseDep - foobar=1.2.3" $ do
        let pn = "foobar=1.2.3"
            p = parseDep pn
        p @?= Just (Dep "foobar" . MustBe . Ideal $ SemVer 1 2 3 [] [])
        fmap renderedDep p @?= Just pn
    ]
  , testGroup "Aura.Types"
    [ testCase "simplepkg"
      $ simplepkg (PackagePath $ fromAbsoluteFilePath "/var/cache/pacman/pkg/linux-is-cool-3.2.14-1-x86_64.pkg.tar.xz")
      @?= Just (SimplePkg "linux-is-cool" . Ideal $ SemVer 3 2 14 [[Digits 1]] [])
    , testCase "simplepkg'"
      $ simplepkg' "xchat 2.8.8-19" @?= Just (SimplePkg "xchat" . Ideal $ SemVer 2 8 8 [[Digits 19]] [])
    ]
  , testGroup "Aura.Packages.Repository"
    [ testCase "extractVersion" $ extractVersion firefox @?= Just (Ideal $ SemVer 60 0 2 [[Digits 1]] [])
    ]
  , testGroup "Aura.Pacman"
    [ testCase "Parsing pacman.conf" $ do
        let p = parse config "pacman.conf" conf
            r = either (const Nothing) (\(Config c) -> Just c) p >>= M.lookup "HoldPkg"
        r @?= Just ["pacman", "glibc"]
    ]
  , testGroup "Aura.Languages"
    [ testCase "Language names are complete" $ do
        case [minBound..maxBound] :: [Language] of
          [] -> assertFailure "No languages found"
          lang:restOfLangs -> do
            let names = languageNames lang
            for_ restOfLangs $ \otherLang -> do
              let otherNames = languageNames otherLang
              assertEqual ("Language name maps for " ++ show lang ++ " and " ++ show otherLang ++ " have different size") (M.size names) (M.size otherNames)
    ]
  , testGroup "Aura.Pkgbuild.Security"
    [ testCase "Parsing - aura.PKGBUILD" $ do
        -- pPrintNoColor $ map (first prettyText) . bannedTerms <$> ppb
        -- pPrintNoColor ppb
        assertBool "Failed to parse" $ isJust ppb
    , testCase "Detecting banned terms" $ (length . bannedTerms <$> ppb) @?= Just 5
    ]
  ]
  where ppb = parsedPB pb

firefox :: T.Text
firefox = "Repository      : extra\n\
\Name            : firefox\n\
\Version         : 60.0.2-1\n\
\Description     : Standalone web browser from mozilla.org"
