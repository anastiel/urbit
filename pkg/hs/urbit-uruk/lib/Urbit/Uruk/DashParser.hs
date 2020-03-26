{-# OPTIONS_GHC -Wall -Werror #-}

module Urbit.Uruk.DashParser where

import ClassyPrelude hiding (exp, init, last, many, some, try)

import Control.Lens
import Control.Monad.State.Lazy
import Text.Megaparsec
import Text.Megaparsec.Char

import Bound            (abstract1)
import Data.Void        (Void, absurd)
import Numeric.Natural  (Natural)
import Prelude          (read)
import Text.Show.Pretty (pPrint)
import Urbit.Atom       (Atom)

import qualified Urbit.Atom         as Atom
import qualified Urbit.Uruk.Bracket as B


-- Types -----------------------------------------------------------------------

infixl 5 :@;

data AST
  = Lam Text AST
  | Var Text
  | AST :@ AST
  | Tag Text
 deriving (Eq, Ord, Show)

pattern App :: AST -> AST -> AST
pattern App x y = x :@ y


-- Parser Monad ----------------------------------------------------------------

data Mode = Wide | Tall

type Parser = StateT Mode (Parsec Void Text)

inWideMode :: Parser a -> Parser a
inWideMode = withLocalState Wide
 where
  withLocalState :: Monad m => s -> StateT s m a -> StateT s m a
  withLocalState val x = do
    old <- get
    put val
    x <* put old


-- Simple Lexers ---------------------------------------------------------------

ace, pal, par :: Parser ()
ace = void (char ' ')
pal = void (char '(')
par = void (char ')')

bulkSpace :: Parser ()
bulkSpace = void (many spaceChar)

gap :: Parser ()
gap = (void (string "  ") <|> void (char '\n')) >> bulkSpace

whitespace :: Parser ()
whitespace = gap <|> ace

sym :: Parser Text
sym =
  fmap pack $ some $ oneOf ("$" <> ['a' .. 'z'] <> ['A' .. 'Z'] <> ['0' .. '9'])


-- Grammar ---------------------------------------------------------------------

exp :: Parser AST
exp = try rune <|> irregular

apN :: [AST] -> AST
apN []       = error "empty function application"
apN [x     ] = x
apN (x : xs) = go x xs
 where
  go acc []       = acc
  go acc (y : ys) = go (acc :@ y) ys

ap3 :: AST -> AST -> AST -> AST
ap3 x y z = apN [x, y, z]

ap4 :: AST -> AST -> AST -> AST -> AST
ap4 x y z p = apN [x, y, z, p]

lam :: [Text] -> AST -> AST
lam binds body = go body binds
 where
  go acc []       = acc
  go acc (b : bs) = Lam b (go acc bs)

irregular :: Parser AST
irregular = inWideMode $ choice
  [ inlineFn
  , apN <$> grouped "(" " " ")" exp
  , Var <$> sym
  , Tag <$> try (char '%' >> sym)
  ]

inlineFn :: Parser AST
inlineFn = do
  char '<'
  binds <- some (try (sym <* char ' '))
  body  <- exp
  char '>'
  pure (lam binds body)

sig :: Parser [Text]
sig = grouped "(" " " ")" sym <|> (: []) <$> sym

rune :: Parser AST
rune = choice
  [ string "|=" *> rune2 lam sig exp
  , string "%-" *> rune2 (:@) exp exp
  , string "%+" *> rune3 ap3 exp exp exp
  , string "%^" *> rune4 ap4 exp exp exp exp
  , string "~/" *> rune3 jet nat sym exp
  ]

jet :: Natural -> Text -> AST -> AST
jet arity name expr = go j arity :@ Tag name :@ expr
 where
  j = Var "J"

  go :: AST -> Natural -> AST
  go _   0 = error "jet: go: bad-arity: 0"
  go acc 1 = acc
  go acc n = go (acc :@ j) (pred n)

nat :: Parser Natural
nat = read <$> some (oneOf ['0' .. '9'])

-- Groups and binders ----------------------------------------------------------

grouped :: Text -> Text -> Text -> Parser a -> Parser [a]
grouped open delim close item = string open >> body
 where
  body = shut <|> (:) <$> item <*> rest
  rest = many (string delim *> item) <* shut
  shut = string close $> []


-- Rune Helpers ----------------------------------------------------------------

{-
    - If the parser is in `Wide` mode, only accept the `wide` form.
    - If the parser is in `Tall` mode, either
      - accept the `tall` form or:
      - swich to `Wide` mode and then accept the wide form.
-}
parseRune ∷ Parser a → Parser a → Parser a
parseRune tall wide = get >>= \case
  Wide → wide
  Tall → tall <|> inWideMode wide

rune1 ∷ (a→b) → Parser a → Parser b
rune1 node x = parseRune tall wide
  where tall = do gap; p←x;      pure (node p)
        wide = do pal; p←x; par; pure (node p)

rune2 ∷ (a→b→c) → Parser a → Parser b → Parser c
rune2 node x y = parseRune tall wide
  where tall = do gap; p←x; gap; q←y;      pure (node p q)
        wide = do pal; p←x; ace; q←y; par; pure (node p q)

rune3 ∷ (a→b→c→d) → Parser a → Parser b → Parser c → Parser d
rune3 node x y z = parseRune tall wide
  where tall = do gap; p←x; gap; q←y; gap; r←z;      pure (node p q r)
        wide = do pal; p←x; ace; q←y; ace; r←z; par; pure (node p q r)

rune4 ∷ (a→b→c→d→e) → Parser a → Parser b → Parser c → Parser d → Parser e
rune4 node x y z g = parseRune tall wide
  where tall = do gap; p←x; gap; q←y; gap; r←z; gap; s←g; pure (node p q r s)
        wide = do pal; p←x; ace; q←y; ace; r←z; ace; s←g; pure (node p q r s)


-- Entry Point -----------------------------------------------------------------

data Dec = Dec Text [Text] AST
  deriving (Show)

decl :: Parser Dec
decl = do
  (n:xs, b) <- string "++" *> rune2 (,) sig exp
  pure (Dec n xs b)

eat :: Parser ()
eat = option () whitespace

dashFile :: Parser [Dec]
dashFile = go []
 where
  go acc = do
    eat
    (eof $> reverse acc <|> (decl >>= go . (: acc)))

parseAST ∷ Text → Either Text AST
parseAST txt =
  runParser (evalStateT exp Tall) "stdin" txt & \case
    Left  e → Left (pack $ errorBundlePretty e)
    Right x → pure x

parseDecs ∷ Text → Either Text [Dec]
parseDecs txt =
  runParser (evalStateT dashFile Tall) "stdin" txt & \case
    Left  e → Left (pack $ errorBundlePretty e)
    Right x → pure x


-- AST to SK -------------------------------------------------------------------

infixl 5 :%;

data SKAG
  = S
  | K
  | A Atom
  | SKAG :% SKAG
 deriving (Show)

skag :: B.Exp Void (B.SK Atom) -> SKAG
skag = \case
  B.Lam b    _  -> absurd b
  x     B.:@ y  -> skag x :% skag y
  B.Var (B.V a) -> A a
  B.Var B.S     -> S
  B.Var B.K     -> K

astExp :: AST -> B.Exp () (Either Atom Text)
astExp = \case
  Var t   -> B.Var $ Right t
  Tag t   -> B.Var $ Left $ Atom.utf8Atom t
  x :@ y  -> astExp x B.:@ astExp y
  Lam n b -> B.Lam () (abstract1 (Right n) (astExp b))

expErr :: B.Exp b (Either Atom Text) -> Either Text (B.Exp b Atom)
expErr = traverse $ \case
  Left atom  -> Right atom
  Right free -> Left ("Undefined Variable: " <> free)

tryExp ∷ Text → Either Text (SKAG, SKAG)
tryExp txt = do
  expr <- parseAST txt
  resu <- expErr (astExp expr)
  pure (skag (B.johnTrompBracket resu), skag (B.naiveBracket resu))

tryIt :: Text -> IO ()
tryIt txt = do
  tryExp txt & \case
    Left err -> putStrLn err
    Right rs -> pPrint rs

tryDash :: IO ()
tryDash = do
  txt <- readFileUtf8 "urbit-uruk/jets.dash"
  parseDecs txt & \case
    Left err -> putStrLn err
    Right ds -> pPrint ds
