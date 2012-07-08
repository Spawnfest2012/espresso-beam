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
-module(wolf).

-behaviour(gen_fsm).

%% API
-export([start_link/0, next_step/1, do_something/2]).

%% gen_fsm callbacks
-export([init/1, idle/2, wait/3, handle_event/3, handle_sync_event/4, handle_info/3, 
         terminate/3, code_change/4]).

-define(SERVER, ?MODULE).

-record(state, {position=nil,
		kinematics=nil,
		health=nil
	       }).

-include("../include/espresso_beam.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_fsm:start_link(?MODULE, [], []).

next_step(Pid) ->
    gen_fsm:send_event(Pid, {next_step}).

do_something(Pid, CellStatus) ->
    gen_fsm:sync_send_event(Pid, {do_something, CellStatus}).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    pg:join(wolves, self()),
    io:format("Spawned new wolf: ~p ~n", [self()]),
    Pos = env_manager:allocate_me(self(), wolf),


    Kin = #actor_kin{},
    {ok, idle, #state{ 
	   position=Pos,
	   kinematics=Kin,
	   health=10
	  }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec state_name(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
idle({next_step}, State) ->
    NewState = State,
    %% %% get the kinematics and the current position
    %% Pos = State#state.position,
    %% Kin = State#state.kinematics,
    %% Health = State#state.health,
    
    %% %% ask the env_manager for the nearby cells
    %% Nearby = env_manager:give_me_close_cells_status(self()),
    
    %% %% check the nearby cells for carrots or wolves
    %% Wolves = lists:filter(fun({{X,Y}, Content}) ->
    %% 				  lists:any(fun(What) ->
    %% 						    case What of {_, wolf} ->
    %% 							    true;
    %% 							_ -> false
    %% 						    end
    %% 					    end,
    %% 					    Content)
    %% 			  end,
    %% 			  Nearby),
    
    %% Carrots = lists:filter(fun({{X,Y}, Content}) ->
    %% 				   lists:any(fun(What) ->
    %% 						     case What of {_, carrot} ->
    %% 							     true;
    %% 							 _ -> false
    %% 						     end
    %% 					     end,
    %% 					     Content)
    %% 			      end,
    %% 			   Nearby),
    
    %% %% according to the content of the nearby cells, take a new behaviour
    %% {NextPos, NewKin} = 
    %% 	if length(Wolves) =/= 0 ->
    %% 		[W|_] = Wolves,
    %% 		kinematics:flee(Kin, W);
	   
    %% 	   length(Carrots) =/= 0 ->
    %% 		[C|_] = Carrots,
    %% 		kinematics:seek(Kin, C);
	   
    %% 	   true ->
    %% 		kinematics:wander(Kin, Pos, Nearby)
    %% 	end,
    
    %% NewState = #state{
    %%   position = NextPos,
    %%   kinematics = NewKin,
    %%   health = Health
    %%  },

    %% %% tell the env_manager the new_position
    NextPos = State#state.position, %% !FIXME wolves are staying still
    env_manager:update_me(self(), NextPos),
    {next_state, wait, NewState}.


%% wait for a list of other actors who are in our same cell
wait({do_something, _OtherActors}, _From, State) ->
    NewState = State,
    %% %% get my health status
    %% Health = State#state.health,
    
    %% %% is there a carrot out there?
    %% Carrots = lists:filter(fun({{X,Y}, Content}) ->
    %% 				   lists:any(fun(What) ->
    %% 						     case What of {_, carrot} ->
    %% 							     true;
    %% 							 _ -> false
    %% 						     end
    %% 					     end,
    %% 					     Content)
    %% 			      end,
    %% 			   OtherActors),
    
    %% if length(Carrots) =/= 0 ->
    %% 	    %% eat it
    %% 	    [C|_] = Carrots,
    %% 	    carrot:eaten(C),
    %% 	    NewState = State#state{ health = Health + 2 };

    %%    true ->
    %% 	    %% else, decrease the health level
    %% 	    NewState = State#state{ health = Health - 1 }
    %% end,


    %% %% if health == 0 -> die
    %% %% else -> go back to idle
    %% if Health == 0 ->
    %% 	    {stop, normal, deallocate_me, NewState};
    %%    true ->
    %% 	    {reply, ok, idle, NewState}
    %% end.
    {reply, ok, idle, NewState}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
