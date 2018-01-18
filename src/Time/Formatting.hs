{-# LANGUAGE AllowAmbiguousTypes  #-}
{-# LANGUAGE CPP                  #-}
{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE InstanceSigs         #-}
{-# LANGUAGE Rank2Types           #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeApplications     #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}

{- | This module introduces function to format time in desired way.

__Examples__

>>> seriesF @'[Day, Hour, Minute, Second] (minute 4000)
"2d18h40m"

>>> seriesF @'[Day, Minute, Second] (minute 4000)
"2d1120m"

>>> seriesF @'[Hour, Minute, Second] (sec 3601)
"1h1s"

>>>  seriesF @'[Hour, Second, Millisecond] (Time @Minute $ 3 % 2)
"90s"

>>> seriesF @'[Hour, Second] (minute 0)
"0h"

The received list should be in descending order. It would be verified at compile-time.
Example of the error from @ghci@:

>>> seriesF @'[Millisecond, Second] (minute 42)

<interactive>:10:2: error:
    • List of units should be in descending order
    • In the expression: seriesF @'[Millisecond, Second] (minute 42)
      In an equation for ‘it’:
          it = seriesF @'[Millisecond, Second] (minute 42)

-}

module Time.Formatting
       ( Series (..)
       , unitsF
       ) where

import Time.Rational (Rat)
#if ( __GLASGOW_HASKELL__ >= 804 )
import GHC.TypeLits (TypeError, ErrorMessage (Text))
import Data.Kind (Constraint)

import Time.Rational (type (>=%), withRuntimeDivRat)
#endif
import Time.Units (AllTimes, KnownRatName, Time, floorUnit, toUnit)

#if ( __GLASGOW_HASKELL__ >= 804 )
-- Type-level 'and'.
type family And (a :: Bool) (b :: Bool) where
  And 'False _ = 'False
  And _      x = x

-- | Type family for verification of the descending order of the given
-- list of time units.
type family IsDescending (units :: [Rat]) :: Bool where
    IsDescending ('[])     = 'True
    IsDescending ('[unit]) = 'True
    IsDescending (unit1 ': unit2 ': units) =
        (unit1 >=% unit2) `And` (IsDescending (unit2 ': units))

type family DescendingConstraint (b :: Bool) :: Constraint where
    DescendingConstraint 'True  = ()  -- empty constraint; always satisfiable
    DescendingConstraint 'False = TypeError ('Text "List of units should be in descending order")
#endif

-- | Class for time formatting.
class Series (units :: [Rat]) where
    seriesF :: forall (someUnit :: Rat) . KnownRatName someUnit
            => Time someUnit
            -> String

instance Series ('[] :: [Rat]) where
    seriesF :: Time someUnit -> String
    seriesF _ = ""

instance ( KnownRatName unit
         , Series units
#if ( __GLASGOW_HASKELL__ >= 804 )
         , DescendingConstraint (IsDescending (unit : units))
#endif
         )
    => Series (unit ': units :: [Rat]) where
    seriesF :: forall (someUnit :: Rat) . KnownRatName someUnit
            => Time someUnit
            -> String
#if ( __GLASGOW_HASKELL__ >= 804 )
    seriesF t = let newUnit = withRuntimeDivRat @someUnit @unit $ toUnit @unit t
#else
    seriesF t = let newUnit = toUnit @unit t
#endif
                    flooredNewUnit = floorUnit newUnit
                    timeStr = case flooredNewUnit of
                                   0 -> ""
                                   _ -> show flooredNewUnit
                    nextUnit = newUnit - flooredNewUnit
                in if nextUnit == 0
                   then show newUnit
                   else timeStr ++ seriesF @units @unit nextUnit

{- | Similar to 'seriesF', but formats using all time units of the library.

>>> unitsF $ fortnight 5
"5fn"

>>> unitsF $ minute 4000
"2d18h40m"

-}
unitsF :: forall unit . KnownRatName unit => Time unit -> String
unitsF = seriesF @AllTimes
