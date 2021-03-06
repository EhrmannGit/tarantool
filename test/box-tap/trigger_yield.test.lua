#!/usr/bin/env tarantool
box.cfg{
    pid_file = "box.pid",
    memtx_memory = 104857600,
    log = "tarantool.log"
}

fiber = require('fiber')

box.schema.space.create('test')
box.space.test:create_index('pk')

box.space.test:truncate()

function fail() fiber.sleep(0.0001) error("fail") end

box.space.test:on_replace(fail)

function insert() box.space.test:auto_increment{fiber.id()} end

fibers = {}
for i = 1, 100 do
    table.insert(fibers, fiber.create(insert))
end

for _,f in pairs(fibers) do
    while f:status() ~= 'dead' do fiber.sleep(0.0001) end
end
print('done: '..box.space.test:len())
box.space.test:drop()
os.exit()
