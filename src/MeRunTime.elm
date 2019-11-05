module MeRunTime exposing
    ( compute
    , computeExpr
    , error
    , getFinalValue
    , getFuncV
    , getValue
    )

import List.Extra
import MeType exposing (..)


computeExpr : Expr -> Expr
computeExpr expr =
    let
        context =
            []
    in
    compute context expr


error : String -> Expr
error s =
    ComputedValue (VError s)


getValue : Context -> Expr -> V
getValue context expr =
    case compute context expr of
        ComputedValue v ->
            v

        SimpleValue v ->
            v

        _ ->
            VError "trying to use uncomputed value"


compute : FV
compute context expr =
    case expr of
        LetIn c resultExpr ->
            compute (c ++ context) resultExpr

        Var _ v ->
            compute context v

        VarName vname ->
            let
                tup =
                    List.Extra.find (\( n, _ ) -> n == vname) context
            in
            case tup of
                Just ( _, v ) ->
                    compute context v

                Nothing ->
                    error ("cannot find " ++ vname)

        ComputedValue v ->
            ComputedValue v

        SimpleValue v ->
            SimpleValue v

        PipeLine topExpr lst ->
            evalPipeLine context topExpr lst

        Call funcName args ->
            let
                funcImpl =
                    List.Extra.find (\( n, _ ) -> n == funcName) context
                        |> Maybe.map Tuple.second

                computedArgs =
                    args
                        |> List.map
                            (\( n, arg ) ->
                                ( n, compute context arg )
                            )
            in
            case funcImpl of
                Just impl ->
                    compute (computedArgs ++ context) impl

                Nothing ->
                    error ("cannot find name in module: " ++ funcName)

        FuncCall ns funcName args ->
            let
                funcImpl =
                    List.Extra.find (\( n, _ ) -> n == funcName) ns
                        |> Maybe.map Tuple.second
            in
            case funcImpl of
                Just impl ->
                    -- there's no type check here, we just populate
                    -- the namespace assuming funcImpl will ask for
                    -- the right names via VarName
                    compute (args ++ ns) impl

                Nothing ->
                    error ("cannot find name in module: " ++ funcName)

        IfElse cond ifExpr elseExpr ->
            case getValue context cond of
                VBool b ->
                    if b then
                        compute context ifExpr

                    else
                        compute context elseExpr

                VError s ->
                    error ("error with if conditional: " ++ s)

                _ ->
                    error "if needs a conditional"

        Infix opLeft binOp opRight ->
            case binOp of
                BinOp _ fvv ->
                    fvv context opLeft opRight

                _ ->
                    error "infix needs a binary operator: "

        F2 fv arg1 arg2 ->
            compute context (F1 (F1 fv arg1) arg2)

        F1 fv arg1 ->
            case fv of
                F1 _ _ ->
                    let
                        newFv =
                            compute context fv
                    in
                    compute context (F1 newFv arg1)

                ComputedFunc f ->
                    f context arg1

                NamedFunc _ f ->
                    f context arg1

                _ ->
                    error "F1 needs a function"

        _ ->
            error "cannot evaluate this type as a value yet"


getFuncV : Context -> Expr -> Result String FV
getFuncV context expr =
    case expr of
        F1 _ _ ->
            compute context expr
                |> getFuncV context

        Var _ v ->
            getFuncV context v

        NamedFunc _ f ->
            Ok f

        ComputedFunc f ->
            Ok f

        LambdaLeft _ binOp opRight ->
            case binOp of
                BinOp _ fvv ->
                    let
                        fv c opLeft =
                            fvv c opLeft opRight
                    in
                    Ok fv

                _ ->
                    Err "lambda left needs a binary operator"

        LambdaRight opLeft binOp _ ->
            case binOp of
                BinOp _ fvv ->
                    let
                        fv c opRight =
                            fvv c opLeft opRight
                    in
                    Ok fv

                _ ->
                    Err "lambda right needs a binary operator"

        _ ->
            Err "not a function"


evalPipeLine : Context -> Expr -> List Expr -> Expr
evalPipeLine context v lst =
    case lst of
        [] ->
            compute context v

        head :: rest ->
            case getFuncV context head of
                Ok f ->
                    let
                        newV =
                            f context v
                    in
                    evalPipeLine context newV rest

                Err s ->
                    error ("wanted function in pipeline: " ++ s)


getFinalValue : Expr -> V
getFinalValue expr =
    case expr of
        ComputedValue v ->
            v

        SimpleValue v ->
            v

        _ ->
            VError "final values were never computed with computeExpr"
