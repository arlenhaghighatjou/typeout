print("Hello world, from client!")

task.spawn(require(script.HandsUp))
task.spawn(require(script.WordInput))
task.spawn(require(script.Announcements))
task.spawn(require(script.RoundHud))
task.spawn(require(script.Spectate))
task.spawn(require(script.Lobby))
