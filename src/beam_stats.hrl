-define(METHOD_SHOULD_NOT_BE_USED(Method, State),
    {stop, {method_should_not_be_used, {?MODULE, Method}}, State}
).
