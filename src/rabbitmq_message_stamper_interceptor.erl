%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ Message Timestamp.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbitmq_message_stamper_interceptor).

-include_lib("rabbit_common/include/rabbit.hrl").
-include_lib("rabbit_common/include/rabbit_framing.hrl").

-behaviour(rabbit_channel_interceptor).

-export([description/0, intercept/3, applies_to/0, init/1]).

-record(message_stamper, {
    id      :: atom(),
    func    :: function()
 }).

-rabbit_boot_step({?MODULE, [
  {description, "message stamper interceptor"},
  {mfa, {rabbit_registry, register, [channel_interceptor, <<"message stamper interceptor">>, ?MODULE]}},
  {cleanup, {rabbit_registry, unregister, [channel_interceptor, <<"message stamper interceptor">>]}},
  {requires, rabbit_registry},
  {enables, recovery}
]}).

init(_Ch) ->
    undefined.

description() ->
    [{description, <<"Adds current stamps to message headers">>}].

intercept(#'basic.publish'{} = Method, EncodedContent, _IState) ->
    lager:info("METHOD: ~p", [Method]),

    Content = rabbit_binary_parser:ensure_content_decoded(EncodedContent),
    {Method, stamp_content(Method, Content)};

intercept(Method, Content, _VHost) ->
    {Method, Content}.

applies_to() ->
    ['basic.publish'].

%%----------------------------------------------------------------------------
stamp_content(Method, Content) ->
    Headers = content_headers(Content),
    lager:info("HEADERS: ~p", [Headers]),

    NewHeaders = lists:foldl(fun(#message_stamper{id = StamperId, func = StamperFunc}, StampedHeaders) ->
        case should_apply_stamper(StamperId, Method) of
            true -> StamperFunc(StampedHeaders);
            false -> StampedHeaders
        end
    end, Headers, stampers()),
    lager:info("NEW_HEADERS: ~p", [NewHeaders]),

    set_content_headers(NewHeaders, Content).

stampers() ->
    [
        #message_stamper{id = timestamp, func = fun(Headers) -> put_header({<<"x-timestamp">>, long, time_compat:os_system_time(seconds)}, Headers) end},
        #message_stamper{id = origin, func = fun(Headers) -> put_header({<<"x-origin">>, longstr, atom_to_binary(node(), latin1)}, Headers) end}
    ].


should_apply_stamper(StamperId, #'basic.publish'{exchange = Exchange}) ->
    case application:get_env(rabbitmq_message_stamper, StamperId) of
        undefined -> true;
        {ok, ExchangesToStamp} -> lists:member(Exchange, ExchangesToStamp)
    end.

content_headers(#content{properties = Props}) ->
    Props#'P_basic'.headers.

set_content_headers(Headers, #content{properties = Props} = Content) ->
    %% we need to reset properties_bin = none so the new properties
    %% get serialized when deliverying the message.
    Content#content{properties = Props#'P_basic'{headers = Headers}, properties_bin = none}.

put_header(Header, undefined) ->
    put_header(Header, []);

put_header({Name, Type, Value}, Headers) ->
    %% do not overwrite existing header value
    case rabbit_misc:table_lookup(Headers, Name) of
        {array, _} -> Headers;
        _ -> rabbit_misc:set_table_value(Headers, Name, Type, Value)
    end.

