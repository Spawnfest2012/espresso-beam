%%%-------------------------------------------------------------------
%%% @author Loris Fichera <loris.fichera@gmail.com> 
%%% @author Mirko Bonadei <mirko.bonadei@gmail.com>
%%% @author Paolo D'Incau <paolo.dincau@gmail.com> 
%%% @copyright (C) 2012, Loris Fichera, Mirko Bonadei, Paolo D'Incau
%%% @doc
%%%
%%% @end
%%% Created :  7 Jul 2012 by Loris Fichera <loris.fichera@gmail.com>
%%%-------------------------------------------------------------------
-module(env_manager).

-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([allocate_me/2, 
	 give_me_close_cells_status/1,
	 update_me/2,
	 deallocate_me/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {actors, environment, pending_updates}).
-record(actor, {pid, type, location}).
-record(environment, { rows=nil,
		       cols=nil
		       %%held_positions
		     }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

allocate_me(ActorPid, ActorType) ->
    gen_server:call(?SERVER, {allocate_me, ActorPid, ActorType}).

give_me_close_cells_status(ActorPid) ->
    gen_server:call(?SERVER, {give_me_close_cells_status, ActorPid}).

update_me(ActorPid, NewPos) ->
    gen_server:cast(?SERVER, {update_me, ActorPid}).

deallocate_me(ActorPid) ->
    gen_server:cast(?SERVER, {deallocate_me, ActorPid}).

%% !FIXME loop needed -> set pending_updates!

%%%===================================================================
%%% gen_server callacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    <<A:32, B:32, C:32>> = crypto:rand_bytes(12),
    random:seed(A,B,C),

    Rows = config_manager:lookup(rows),
    Columns = config_manager:lookup(columns),
    Env = #environment{rows = Rows,
		       cols = columns
		       },
    
    {ok, #state{actors=[],
		environment=Env,
		pending_updates=0
	       }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({allocate_me, ActorPid, ActorType}, _From, State) ->
    Actors = State#state.actors,
    Env = State#state.environment,
    Location = get_free_position(Env, Actors),
    
    Actor = #actor{pid=ActorPid, type=ActorType, location=Location},
    {reply, Location, State#state{actors=[Actor|Actors]}};


handle_call({give_me_close_cells_status, ActorPid, ActorType}, _From, State) ->
    Env = State#state.environment,
    Actors = State#state.actors,
    {_, _, Location} = proplists:lookup(ActorPid, Actors),
    
    %% get nearby locations
    NearbyLocations = get_nearby_locations(Location, 
					   Env#environment.rows,
					   Env#environment.cols),
    
    %% find out what are the close actors
    %% [{Pos, [ListOfActors]}]
    Reply = 
	list:foldl(fun(Loc, Acc0) ->
			   [{Loc, 
			     lists:foldl(fun(A, Acc1) ->
						 {P, T, ActorPos} = A,
						 if Loc == ActorPos -> [{P,T}|Acc1];
						    true -> Acc1
						 end
					 end,
					 [],
					 Actors)} | Acc0]
		   end,
		   [],
		   NearbyLocations),

    {reply, Reply, State};


handle_call(_Request, _From, State) ->
    io:format("~p~n", [State#state.actors]),
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
%% !FIXME to be implemented
handle_cast({deallocate_me, ActorPid}, #state{actors=Actors} = State) ->
    NewActors = lists:keydelete(ActorPid, #actor.pid, Actors),
    {noreply, State#state{actors=NewActors}};

handle_cast({update_me, ActorPid, NewPos}, State) ->
    %% update the position
    Actors = State#state.actors,
    {_, _, Location} = proplists:lookup(ActorPid, Actors),
    
    NewActors = 
	lists:foldl(fun({P, T, L}, Acc) ->
			    if P == ActorPid -> [{P, T, NewPos}|Acc];
			       true -> [{P, T, L}|Acc]
			    end
		    end,
		    [],
		    Actors),
    
    %% now, let's decrement the counter of pending updates
    NewPendingUpds = State#state.pending_updates - 1,
    
    SurvivedActors = 
	if NewPendingUpds == 0 -> perform_life_cycle(NewActors);
	   true -> NewActors
	end,

    NewState = State#state { actors=SurvivedActors,
			     pending_updates=NewPendingUpds
			   },

    {noreply, NewState};


handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_free_position(Environment, _Actors) ->
    %% !FIXME maybe we shouldn't put two actors in the same cell?
    Rows = Environment#environment.rows,
    Cols = Environment#environment.cols,
    
    RandomLocation = { random:uniform(Rows), 
		       random:uniform(Cols) }.


    %% %% check whether the location is already taken
    %% IsTaken = lists:any(fun({{X,Y}, What}) ->
    %% 				{X,Y} == RandomLocation
    %% 			end,
    %% 			HeldPositions),
    
    %% case IsTaken of true ->
    %% 	    get_free_position(Environment);
    %% 	_ ->
    %% 	    RandomLocation
    %% end.
    
get_nearby_locations({X,Y}, MaxRows, MaxCols) ->
    %% get all nearby locations
    NB = [{Z,A} || Z <- [X-1, X, X+1],
		   A <- [Y-1, Y, Y+1]],
    
    %% discard all invalid positions
    filter_out_invalid_locations(NB, MaxRows, MaxCols).


filter_out_invalid_locations([], MaxRows, MaxCols, Acc) ->
    lists:reverse(Acc);

filter_out_invalid_locations([{X,Y}|Rest], MaxRows, MaxCols, Acc) ->
    if (X < 0) or (Y < 0) or
       (X > MaxCols) or (Y > MaxRows) -> 
	    filter_out_invalid_locations(Rest, MaxRows, MaxCols, Acc);
       
       true ->
	    filter_out_invalid_locations(Rest, MaxRows, MaxCols, [{X,Y}|Acc])
    end.

filter_out_invalid_locations(ListOfPos, MaxRows, MaxCols) ->
    filter_out_invalid_locations(ListOfPos, MaxRows, MaxCols, []).
    

perform_life_cycle(Actors) ->
    perform_life_cycle(Actors, Actors).

perform_life_cycle([], Actors) -> Actors;
perform_life_cycle([{Actor, Type, Location}|Rest], Actors) -> 
    CellStatus = 
	lists:foldl(fun({A, T, L}, Acc) ->
			    if (Location == L) and 
			       (Actor =/= A) -> [{A, T}|Acc];
			       true -> Acc
			    end
		    end,
		    [],
		    Actors),

    Reply = Type:do_something(Actor, CellStatus),
	
    %% delete the actor, if it died
    NewActors = 
	case Reply of deallocate_me -> proplists:delete(Actor, Actors);
	    _ -> Actors
	end,

    perform_life_cycle(Rest, NewActors).
