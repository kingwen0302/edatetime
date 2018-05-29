%% @doc: datetime stuff
-module(edatetime).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([date2ts/1, datetime2ts/1,
         ts2date/1, ts2datetime/1,
         now2us/1, now2ms/0, now2ms/1, now2ts/0, now2ts/1,
         range/3,
         map/4, foldl/5,
         shift/3,
         minute_start/1, hour_start/1, day_start/1, week_start/1, month_start/1,
         second_diff/2, minute_diff/2, hour_diff/2
        ]).

-export([iso8601/1, iso8601_basic/1]).
-export([tomorrow/1, yesterday/1]).

-type timestamp() :: pos_integer().
-type year()      :: pos_integer().
-type month()     :: pos_integer().
-type day()       :: pos_integer().
-type hour()      :: pos_integer().
-type minute()    :: pos_integer().
-type second()    :: pos_integer().
-type datetime()  :: {{year(), month(), day()}, {hour(), minute(), second()}}.
-type date()      :: {year(), month(), day()}.
-export_type([timestamp/0, datetime/0, date/0]).

-spec date2ts(date()) -> timestamp().
date2ts({Y, M, D}) ->
    calendar:datetime_to_gregorian_seconds({{Y, M, D}, {0, 0, 0}})
    - calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0,0,0}}).

-spec datetime2ts(datetime()) -> timestamp().
datetime2ts(Datetime) ->
    DateTime1970 = calendar:universal_time_to_local_time({{1970,1,1},{0,0,0}}),
    calendar:datetime_to_gregorian_seconds(Datetime)
    - calendar:datetime_to_gregorian_seconds(DateTime1970).

-spec ts2date(timestamp()) -> date().
ts2date(Timestamp) ->
    {Date, _Time} = ts2datetime(Timestamp),
    Date.

-spec ts2datetime(timestamp()) -> datetime().
ts2datetime(Timestamp) ->
    DateTime1970 = calendar:universal_time_to_local_time({{1970,1,1},{0,0,0}}),
    BaseDate = calendar:datetime_to_gregorian_seconds(DateTime1970),
    Seconds = BaseDate + Timestamp,
    calendar:gregorian_seconds_to_datetime(Seconds).


now2us({MegaSecs,Secs,MicroSecs}) ->
    (MegaSecs * 1000000 + Secs) * 1000000 + MicroSecs.

now2ms() ->
    now2ms(os:timestamp()).

now2ms({MegaSecs,Secs,MicroSecs}) ->
    (MegaSecs * 1000000 + Secs) * 1000 + (MicroSecs div 1000).

-spec now2ts() -> timestamp().
now2ts() ->
    now2ts(os:timestamp()).

now2ts({MegaSeconds, Seconds, _}) ->
    MegaSeconds * 1000000 + Seconds.

range(Start, End, Interval) ->
    map(fun (E) -> E end, Start, End, Interval).


map(F, Start, End, Period) when Start =< End ->
    Align = case Period of
                days -> fun day_start/1;
                hours -> fun hour_start/1;
                minutes -> fun minute_start/1;
                seconds -> fun (X) -> X end
            end,

    do_map(F, Align(Start), Align(End), Period, []);
map(_, _, _, _) ->
    error(badarg).


do_map(F, End, End, _Period, Acc) ->
    lists:reverse([F(End) | Acc]);
do_map(F, Start, End, Period, Acc) ->
    do_map(F, shift(Start, 1, Period), End, Period, [F(Start) | Acc]).



foldl(F, Acc0, Start, End, hours) ->
    do_foldl(F, Start, End, hours, Acc0);
foldl(F, Acc0, Start, End, days) ->
    do_foldl(F, day_start(Start), day_start(End), days, Acc0).

do_foldl(F, End, End, _Period, Acc) ->
    F(End, Acc);
do_foldl(F, Start, End, Period, Acc) ->
    do_foldl(F, shift(Start, 1, Period), End, Period, F(Start, Acc)).



shift(Ts, N, days)    -> Ts + (N * 86400);
shift(Ts, N, day)     -> Ts + (N * 86400);
shift(Ts, N, hours)   -> Ts + (N * 3600);
shift(Ts, N, hour)    -> Ts + (N * 3600);
shift(Ts, N, minutes) -> Ts + (N * 60);
shift(Ts, N, minute)  -> Ts + (N * 60);
shift(Ts, N, seconds) -> Ts + N.

day_start(Ts)    ->
    NewTs = time_fix(Ts),
    Ts - (NewTs rem 86400).
hour_start(Ts)   ->
    NewTs = time_fix(Ts),
    Ts - (NewTs rem 3600).
minute_start(Ts) ->
    NewTs = time_fix(Ts),
    Ts - (NewTs rem 60).

time_fix(Ts) ->
    DateTime1970 = calendar:universal_time_to_local_time({{1970,1,1},{0,0,0}}),
    TimeFix = calendar:datetime_to_gregorian_seconds(DateTime1970) - calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
    Ts + TimeFix.

week_start(Ts) ->
    WeekDay = calendar:day_of_the_week(ts2date(Ts)),
    day_start(shift(Ts, -WeekDay+1, days)).

month_start(Ts) ->
    {Y, M, _} = ts2date(Ts),
    date2ts({Y, M, 1}).


tomorrow(Ts) ->
    shift(Ts, 1, days).

yesterday(Ts) ->
    shift(Ts, -1, days).


second_diff(TsA, TsB) -> float((TsA - TsB)).
minute_diff(TsA, TsB) -> float((TsA - TsB) / 60).
hour_diff(TsA, TsB)   -> float((TsA - TsB) / (60 * 60)).



%%
%% Serialization
%%

iso8601(Ts) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = edatetime:ts2datetime(Ts),
    list_to_binary(
      io_lib:format("~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0BZ",
                    [Year, Month, Day, Hour, Minute, Second])).

iso8601_basic(Ts) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = edatetime:ts2datetime(Ts),
    list_to_binary(
      io_lib:format("~4.10.0B~2.10.0B~2.10.0BT~2.10.0B~2.10.0B~2.10.0BZ",
                    [Year, Month, Day, Hour, Minute, Second])).



%%
%% TESTS
%%

-ifdef(TEST).

shift_test() ->
    ?assertEqual(datetime2ts({{2013, 1, 1}, {1, 0, 0}}),
                 shift(datetime2ts({{2013, 1, 1}, {1, 0, 0}}), 0, days)),

    ?assertEqual(datetime2ts({{2013, 1, 1}, {1, 0, 0}}),
                 shift(datetime2ts({{2013, 1, 1}, {0, 0, 0}}), 1, hour)),

    ?assertEqual(datetime2ts({{2013, 1, 1}, {0, 10, 0}}),
                 shift(datetime2ts({{2013, 1, 1}, {0, 0, 0}}), 10, minutes)),

    ?assertEqual(datetime2ts({{2013, 1, 1}, {0, 0, 10}}),
                 shift(datetime2ts({{2013, 1, 1}, {0, 0, 0}}), 10, seconds)).

day_start_test() ->
    ?assertEqual(datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                 day_start(datetime2ts({{2013, 1, 1}, {0, 0, 0}}))),
    ?assertEqual(datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                 day_start(datetime2ts({{2013, 1, 1}, {0, 10, 0}}))),

    ?assertEqual(datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                 day_start(datetime2ts({{2013, 1, 1}, {23, 59, 59}}))).

week_start_test() ->
    ?assertEqual({2013, 1, 7}, ts2date(week_start(date2ts({2013, 1, 7})))),
    ?assertEqual({2013, 1, 7}, ts2date(week_start(date2ts({2013, 1, 8})))),
    ?assertEqual({2012, 12, 31}, ts2date(week_start(date2ts({2013, 1, 1})))),
    ?assertEqual({2012, 12, 31}, ts2date(week_start(date2ts({2013, 1, 2})))).

month_start_test() ->
    ?assertEqual({2013, 1, 1}, ts2date(month_start(date2ts({2013, 1, 1})))),
    ?assertEqual({2013, 1, 1}, ts2date(month_start(date2ts({2013, 1, 2})))),
    ?assertEqual({2013, 1, 1}, ts2date(month_start(date2ts({2013, 1, 31})))),
    ?assertEqual({2013, 2, 1}, ts2date(month_start(date2ts({2013, 2, 28})))).

map_days_test() ->
    ?assertEqual([{2012, 12, 31},
                  {2013, 1, 1},
                  {2013, 1, 2}],
                 map(fun ts2date/1,
                     date2ts({2012, 12, 31}) + 1,
                     date2ts({2013, 1, 2}) + 2,
                     days)),

    ?assertEqual([{2013, 1, 1}], map(fun ts2date/1,
                                     datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                                     datetime2ts({{2013, 1, 1}, {0, 0, 1}}),
                                     days)),

    ?assertError(badarg, map(fun ts2date/1,
                             datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                             datetime2ts({{2012, 12, 31}, {0, 0, 0}}),
                             days)).

map_hours_test() ->
    ?assertEqual([{{2012, 12, 31}, {0, 0, 0}},
                  {{2012, 12, 31}, {1, 0, 0}},
                  {{2012, 12, 31}, {2, 0, 0}}
                 ],
                 map(fun ts2datetime/1,
                     datetime2ts({{2012, 12, 31}, {0, 0, 0}}),
                     datetime2ts({{2012, 12, 31}, {2, 5, 0}}),
                     hours)),
    ?assertEqual([{{2012, 12, 31}, {0, 0, 0}}],
                 map(fun ts2datetime/1,
                     datetime2ts({{2012, 12, 31}, {0, 0, 0}}),
                     datetime2ts({{2012, 12, 31}, {0, 0, 0}}),
                     hours)).

range_test() ->
    ?assertEqual([date2ts({2012, 12, 31}),
                  date2ts({2013, 1, 1}),
                  date2ts({2013, 1, 2})],
                 range(date2ts({2012, 12, 31}), date2ts({2013, 1, 2}), days)),
    ?assertEqual([datetime2ts({{2012, 12, 31}, {23, 0 ,0}}),
                  datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                  datetime2ts({{2013, 1, 1}, {1, 0, 0}})],
                 range(datetime2ts({{2012, 12, 31}, {23, 0, 0}}),
                       datetime2ts({{2013, 1, 1}, {1, 0, 0}}), hours)).


foldl_days_test() ->
    ?assertEqual([{2012, 12, 31},
                  {2013, 1, 1},
                  {2013, 1, 2}],
                 lists:reverse(
                   foldl(fun (Ts, Acc) -> [ts2date(Ts) | Acc] end,
                         [],
                         date2ts({2012, 12, 31}) + 1,
                         date2ts({2013, 1, 2}) + 2,
                         days))).

foldl_count_days_test() ->
    ?assertEqual(367,
                 foldl(fun (_, Count) -> Count + 1 end,
                       0,
                       date2ts({2012, 1, 1}),
                       date2ts({2013, 1, 1}),
                       days)).

tomorrow_test() ->
    ?assertEqual(datetime2ts({{2013, 1, 2}, {0, 1, 0}}),
                 tomorrow(datetime2ts({{2013, 1, 1}, {0, 1, 0}}))),
    ?assertEqual(datetime2ts({{2012, 12, 31}, {0, 1, 0}}),
                 yesterday(datetime2ts({{2013, 1, 1}, {0, 1, 0}}))).

iso8601_test() ->
    Ts = datetime2ts({{2013, 1, 2}, {10, 11, 12}}),
    ?assertEqual(<<"2013-01-02T10:11:12Z">>, iso8601(Ts)),
    ?assertEqual(<<"20130102T101112Z">>, iso8601_basic(Ts)).


diff_test() ->
    ?assertEqual(10.0, second_diff(datetime2ts({{2013, 1, 1}, {0, 0, 10}}),
                                   datetime2ts({{2013, 1, 1}, {0, 0, 0}}))),
    ?assertEqual(-10.0, second_diff(datetime2ts({{2013, 1, 1}, {0, 0, 0}}),
                                    datetime2ts({{2013, 1, 1}, {0, 0, 10}}))),

    ?assertEqual(10.0, minute_diff(datetime2ts({{2013, 1, 1}, {0, 10, 0}}),
                                   datetime2ts({{2013, 1, 1}, {0, 0, 0}}))),
    ?assertEqual(10.5, minute_diff(datetime2ts({{2013, 1, 1}, {0, 10, 30}}),
                                   datetime2ts({{2013, 1, 1}, {0, 0, 0}}))),

    ?assertEqual(1.0, hour_diff(datetime2ts({{2013, 1, 1}, {2, 0, 0}}),
                                datetime2ts({{2013, 1, 1}, {1, 0, 0}}))).

-endif.
