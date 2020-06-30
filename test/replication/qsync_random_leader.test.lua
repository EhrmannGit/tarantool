os = require('os')
env = require('test_run')
math = require('math')
fiber = require('fiber')
test_run = env.new()
log = require('log')

orig_synchro_quorum = box.cfg.replication_synchro_quorum
orig_synchro_timeout = box.cfg.replication_synchro_timeout

NUM_INSTANCES = 5
SERVERS = {}
for i=1,NUM_INSTANCES do                                                       \
    SERVERS[i] = 'qsync' .. i                                                  \
end;
SERVERS -- print instance names

math.randomseed(os.time())
random = function(excluded_num, total)                                         \
    local r = math.random(1, total)                                            \
    if (r == excluded_num) then                                                \
        return random(excluded_num, total)                                     \
    end                                                                        \
    return r                                                                   \
end

-- Write value on current leader.
-- Pick a random replica in a cluster.
-- Promote replica to leader.
-- Make sure value is there.

-- Testcase setup.
test_run:create_cluster(SERVERS)
test_run:wait_fullmesh(SERVERS)
test_run:switch('qsync1')
_ = box.schema.space.create('sync', {is_sync=true, engine = test_run:get_cfg('engine')})
_ = box.space.sync:create_index('primary')
test_run:switch('default')
current_leader_id = 1
test_run:eval(SERVERS[current_leader_id], "box.ctl.clear_synchro_queue()")

-- Testcase body.
for i=1,300 do                                                                 \
    test_run:eval(SERVERS[current_leader_id],                                  \
        string.format("box.space.sync:insert{%d}", i))                         \
    new_leader_id = random(current_leader_id, #SERVERS)                        \
    log.info(string.format("current leader id %d, new leader id %d",           \
                           current_leader_id, new_leader_id))                  \
    test_run:eval(SERVERS[new_leader_id], "box.ctl.clear_synchro_queue()")     \
    replica = random(new_leader_id, #SERVERS)                                  \
    test_run:wait_cond(function() return test_run:eval(SERVERS[replica],       \
                       string.format("box.space.sync:get{%d}", i)) ~= nil end) \
    test_run:wait_cond(function() return test_run:eval(SERVERS[current_leader_id], \
                       string.format("box.space.sync:get{%d}", i)) ~= nil end) \
    current_leader_id = new_leader_id                                          \
end

test_run:switch('qsync1')
box.space.sync:count() -- 300

-- Teardown.
test_run:switch('default')
test_run:eval(SERVERS[current_leader_id], 'box.space.sync:drop()')
test_run:drop_cluster(SERVERS)
box.cfg{                                                                       \
    replication_synchro_quorum = orig_synchro_quorum,                          \
    replication_synchro_timeout = orig_synchro_timeout,                        \
}
