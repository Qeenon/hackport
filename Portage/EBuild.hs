module Portage.EBuild
        ( EBuild(..)
        , ebuildTemplate
        ) where

import Distribution.Text ( Text(..), display )
import qualified Text.PrettyPrint as Disp

import Portage.Dependency

import Distribution.License as Cabal

data EBuild = EBuild {
    name :: String,
    version :: String,
    description :: String,
    homepage :: String,
    src_uri :: String,
    license :: Cabal.License,
    slot :: String,
    keywords :: [String],
    iuse :: [String],
    depend :: [Dependency],
    depend_extra :: [String],
    rdepend :: [Dependency],
    rdepend_extra :: [String],
    features :: [String],
    my_pn :: Maybe String --If the package's name contains upper-case
  }

ebuildTemplate :: EBuild
ebuildTemplate = EBuild {
    name = "foobar",
    version = "0.1",
    description = "",
    homepage = "",
    src_uri = "",
    license = Cabal.UnknownLicense "xxx UNKNOWN xxx",
    slot = "0",
    keywords = ["~amd64","~x86"],
    iuse = [],
    depend = [],
    depend_extra = [],
    rdepend = [],
    rdepend_extra = [],
    features = [],
    my_pn = Nothing
  }

instance Text EBuild where
  disp = Disp.text . showEBuild

showEBuild :: EBuild -> String
showEBuild ebuild =
  ss "# Copyright 1999-2010 Gentoo Foundation". nl.
  ss "# Distributed under the terms of the GNU General Public License v2". nl.
  ss "# $Header:  $". nl.
  nl.
  ss "CABAL_FEATURES=". quote' (sepBy " " $ features ebuild). nl.
  ss "inherit haskell-cabal". nl.
  nl.
  (case my_pn ebuild of
     Nothing -> id
     Just pn -> ss "MY_PN=". quote pn. nl.
                ss "MY_P=". quote "${MY_PN}-${PV}". nl. nl).
  ss "DESCRIPTION=". quote (description ebuild). nl.
  ss "HOMEPAGE=". quote (homepage ebuild). nl.
  ss "SRC_URI=". quote (replaceVars (src_uri ebuild)).
     (if null (src_uri ebuild) then ss "\t#Fixme: please fill in manually"
         else id). nl.
  nl.
  ss "LICENSE=". quote (convertLicense . license $ ebuild).
     (if null (licenseComment . license $ ebuild) then id
         else ss "\t#". ss (licenseComment . license $ ebuild)). nl.
  ss "SLOT=". quote (slot ebuild). nl.
  ss "KEYWORDS=". quote' (sepBy " " $ keywords ebuild).nl.
  ss "IUSE=". quote' (sepBy ", " $ iuse ebuild). nl.
  nl.
  dep_str "RDEPEND" (rdepend_extra ebuild) (rdepend ebuild).
  dep_str "DEPEND"  ( depend_extra ebuild) ( depend ebuild).
  nl.
  (case my_pn ebuild of
     Nothing -> id
     Just _ -> nl. ss "S=". quote ("${WORKDIR}/${MY_P}"). nl)
  $ []
  where replaceVars = replaceCommonVars (name ebuild) (my_pn ebuild) (version ebuild)

ss :: String -> String -> String
ss = showString

sc :: Char -> String -> String
sc = showChar

nl :: String -> String
nl = sc '\n'

dep_str :: String -> [String] -> [Dependency] -> (String -> String)
dep_str var extra deps = ss var. sc '='. quote' (sepBy "\n\t\t" $ extra ++ map display deps). nl

quote :: String -> String -> String
quote str = sc '"'. ss str. sc '"'

quote' :: (String -> String) -> String -> String
quote' str = sc '"'. str. sc '"'

sepBy :: String -> [String] -> ShowS
sepBy _ []     = id
sepBy _ [x]    = ss x
sepBy s (x:xs) = ss x. ss s. sepBy s xs

getRestIfPrefix ::
	String ->	-- ^ the prefix
	String ->	-- ^ the string
	Maybe String
getRestIfPrefix (p:ps) (x:xs) = if p==x then getRestIfPrefix ps xs else Nothing
getRestIfPrefix [] rest = Just rest
getRestIfPrefix _ [] = Nothing

subStr ::
	String ->	-- ^ the search string
	String ->	-- ^ the string to be searched
	Maybe (String,String)  -- ^ Just (pre,post) if string is found
subStr sstr str = case getRestIfPrefix sstr str of
	Nothing -> if null str then Nothing else case subStr sstr (tail str) of
		Nothing -> Nothing
		Just (pre,post) -> Just (head str:pre,post)
	Just rest -> Just ([],rest)

replaceMultiVars ::
	[(String,String)] ->	-- ^ pairs of variable name and content
	String ->		-- ^ string to be searched
	String 			-- ^ the result
replaceMultiVars [] str = str
replaceMultiVars whole@((pname,cont):rest) str = case subStr cont str of
	Nothing -> replaceMultiVars rest str
	Just (pre,post) -> (replaceMultiVars rest pre)++pname++(replaceMultiVars whole post)

replaceCommonVars ::
	String ->	-- ^ PN
	Maybe String ->	-- ^ MYPN
	String ->	-- ^ PV
	String ->	-- ^ the string to be replaced
	String
replaceCommonVars pn mypn pv str
	= replaceMultiVars
		([("${P}",pn++"-"++pv)]
		++ maybe [] (\x->[("${MY_P}",x++"-"++pv)]) mypn
		++[("${PN}",pn)]
		++ maybe [] (\x->[("${MY_PN}",x)]) mypn
		++[("${PV}",pv)]) str


-- map the cabal license type to the gentoo license string format
convertLicense :: Cabal.License -> String
convertLicense (Cabal.GPL mv)     = "GPL-" ++ (maybe "2" display mv)  -- almost certainly version 2
convertLicense (Cabal.LGPL mv)    = "LGPL-" ++ (maybe "2.1" display mv) -- probably version 2.1
convertLicense Cabal.BSD3         = "BSD"
convertLicense Cabal.BSD4         = "BSD-4"
convertLicense Cabal.PublicDomain = "public-domain"
convertLicense Cabal.AllRightsReserved = ""
convertLicense Cabal.MIT          = "MIT"
convertLicense _                  = ""

licenseComment :: Cabal.License -> String
licenseComment Cabal.AllRightsReserved =
  "Note: packages without a license cannot be included in portage"
licenseComment Cabal.OtherLicense =
  "Fixme: \"OtherLicense\", please fill in manually"
licenseComment (Cabal.UnknownLicense _) = "Fixme: license unknown to cabal"
licenseComment _ = ""
