module MeElmCode exposing (toElmCode)

{--

Given an Expr written for the ME runtime, this
generates the equivalent Elm code.

This code is not meant to be executed--it's meant
more for documentation.  To actually evaluate the
Expr, use the ME runtime.

Of course, nothing is stopping you from running the
Elm code that gets generated here, but that would
require some tooling.
--}

import MeRepr
import MeType exposing (..)


toElmCode : Expr -> String
toElmCode topExpr =
    let
        withParens s =
            "(" ++ s ++ ")"

        withoutParens s =
            s

        toCode parenWrapper expr =
            case expr of
                Var name _ ->
                    -- TODO: make let statements
                    name

                VarName name ->
                    name

                FunctionCall calledFunc _ ->
                    -- TODO: show call
                    toCode withoutParens calledFunc

                SimpleValue v ->
                    MeRepr.fromVal v

                UserFunction _ _ f ->
                    -- TODO: show definition
                    toCode withoutParens f

                PipeLine a lst ->
                    a
                        :: lst
                        |> List.map (toCode withoutParens)
                        |> String.join "\n    |> "

                FunctionV name _ ->
                    name

                FunctionVV name _ ->
                    name

                BinOp opname vname _ ->
                    "\\"
                        ++ vname
                        ++ " -> "
                        ++ vname
                        ++ " "
                        ++ opname

                Curry fvvExpr curryExpr ->
                    toCode withParens fvvExpr
                        ++ " "
                        ++ toCode withParens curryExpr
                        |> parenWrapper

                ComposeF name exprF _ ->
                    name
                        ++ " "
                        ++ toCode withParens exprF
                        |> parenWrapper

                _ ->
                    " ? "
    in
    toCode withoutParens topExpr
