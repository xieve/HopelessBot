local discordia = require('discordia')
local json = require('json')
local cmd = require('command')
local client = discordia.Client()

local prefix = '!!'
local separator = '\\'

local function writeTable(filename, tbl)
  local file = io.open(filename, 'w')
  file:write(json.encode(tbl))
  file:close()
end

local function readTable(filename)
  local file = io.open(filename, 'r')
  local data = json.decode(file:read('*all'))
  file:close()
  if data then
    return data
  else
    return {}
  end
end

function string.toCISPattern(pattern)
  -- find an optional '%' followed by any character
  local p = pattern:gsub('(%%?)(.)', function(percent, letter)

    if percent ~= '' or not letter:match('%a') then
      -- if the '%' matched, or `letter` is not a letter, return 'as is'
      return percent .. letter
    else
      -- else, return a case-insensitive character class of the matched letter
      return string.format('[%s%s]', letter:lower(), letter:upper())
    end
  end)
  return p
end

function string.escape(rawStr, type)
  if type == 'gsub' then
    return string.gsub(rawStr, '[%%%(%)%.%+%-%*%?%[%^%$]', function (str)
      return '%'..str
    end)
  elseif type == 'format' then
    return string.gsub(rawStr, '[%%]', function (str)
      return '%'..str
    end)
  end
end

local triggerTable = readTable('triggers.json')

client:on('ready', function()
  print('Logged in as '.. client.user.username)
  client:setGameName(prefix..'help')
  triggerTable.global = triggerTable.global or {}
end)

client:on('messageCreate', function(message)
  print(os.date('!%Y-%m-%d %H:%M:%S', message.createdAt).. ' <'.. message.author.name.. '> '.. message.content)
  if message.author.bot == true then return end

  local command = cmd.separate(message.content, prefix, separator)

  if command then
    triggerTable[message.guild.id] = triggerTable[message.guild.id] or {}
    if command.main == 'add' then
      if not command.args[1] or not command.args[2] then
        message:reply
        {
          embed =
          {
            title = 'Syntax:',
            description = prefix..'add <trigger>/<response>[/local]',
            color = discordia.Color(255, 0, 0).value
          }
        }
      elseif (command.args[1]:gsub('§§', '') or command.args[1]):len() < 3 or (command.args[2]:gsub('§§', '') or command.args[2]):len() < 3 then
        message:reply
        {
          embed =
          {
            title = 'Sorry, but the trigger and the response (without `§§`) have to be at least 3 characters long.',
            color = discordia.Color(255, 0, 0).value
          }
        }
      elseif message.content:find('\n') then
        message:reply
        {
          embed =
          {
            title = 'Sorry, but neither the trigger nor the response may contain more than 1 line.',
            color = discordia.Color(255, 0, 0).value
          }
        }
      else
        local triggerExist
        for key, value in pairs(triggerTable) do
          if pcall(function () return value.trigger.raw:lower() == command.args[1]:lower() end) then
            message:reply
            {
              embed =
              {
                title = 'Sorry, but this trigger does already exist.',
                color = discordia.Color(255, 0, 0).value
              }
            }
            triggerExist = true
            break
          end
        end
        if not triggerExist then
          message:reply
          {
            embed =
            {
              title = 'New'..(command.args[3] == 'true' and ' local ' or ' ')..'trigger created:',
              color = discordia.Color(0, 255, 0).value,
              fields =
              {
                {
                  name = 'Trigger',
                  value = command.args[1],
                  inline = 1
                },
                {
                  name = 'Response',
                  value = command.args[2],
                  inline = 1
                }
              }
            }
          }
          if command.args[3] == 'true' then
            triggerTable[message.guild.id] = triggerTable[message.guild.id] or {}
            table.insert(triggerTable[message.guild.id],
              {
                trigger =
                {
                  raw = command.args[1],
                  pattern = command.args[1]:escape('gsub'):toCISPattern():gsub('§§', '(.+)')
                },
                response =
                {
                  raw = command.args[2],
                  pattern = command.args[2]:escape('format'):gsub('§§', '%%s')
                }
              }
            )
          else
            table.insert(triggerTable.global,
              {
                trigger =
                {
                  raw = command.args[1],
                  pattern = command.args[1]:escape('gsub'):toCISPattern():gsub('§§', '(.+)')
                },
                response =
                {
                  raw = command.args[2],
                  pattern = command.args[2]:escape('format'):gsub('§§', '%%s')
                }
              }
            )
          end
          writeTable('triggers.json', triggerTable)
        end
      end
    elseif command.main == 'del' and message.author.id == client.owner.id then
      local deleted = false

      for key, value in pairs(triggerTable[message.guild.id]) do
        if command.args[1] == value.trigger.raw then
          deleted = value
          triggerTable[message.guild.id][key] = nil
          break
        end
      end

      if not deleted then
        for key, value in pairs(triggerTable.global) do
          if command.args[1] == value.trigger.raw then
            deleted = value
            triggerTable.global[key] = nil
            break
          end
        end
      end

      if deleted then
        message:reply{
          embed =
          {
            title = 'Deleted Trigger:',
            color = discordia.Color(0, 0, 255).value,
            fields =
            {
              {
                name = 'Trigger',
                value = deleted.trigger.raw,
                inline = 1
              },
              {
                name = 'Response',
                value = deleted.response.raw,
                inline = 1
              }
            }
          }
        }
        writeTable('triggers.json', triggerTable)
      else
        message:reply
        {
          embed =
          {
            title = 'Sorry, but this trigger doesn\'t exist.',
            color = discordia.Color(255, 0, 0).value
          }
        }
      end
    elseif command.main == 'list' then
      local triggers = ''
      local responses = ''
      for key, value in pairs(triggerTable.global) do
        triggers = triggers..value.trigger.raw..'\n'
        responses = responses..value.response.raw..'\n'
      end
      for key, value in pairs(triggerTable[message.guild.id]) do
        triggers = triggers..value.trigger.raw..'\n'
        responses = responses..value.response.raw..'\n'
      end
      if triggers == '' and responses == '' then
        message:reply
        {
          embed =
          {
            title = 'Sorry, but there are no triggers.',
            color = discordia.Color(255, 0, 0).value
          }
        }
      else
        message:reply
        {
          embed =
          {
            title = 'Here are all the Triggers:',
            fields =
            {
              {
                name = 'Trigger',
                value = triggers,
                inline = 1
              },
              {
                name = 'Response',
                value = responses,
                inline = 1
              }
            }
          }
        }
      end
    elseif command.main == 'help' then
      if command.args[1]:lower():match('^triggers?$') then
        message:reply{
          embed = {
            title = 'Triggers work like this:',
            fields =
            {
              {
                name = prefix..'add <trigger>'..separator..'<response>['..separator..'local]',
                value = 'Create a trigger. Set local to true if you want that trigger to only work on this server. You can set a relative attribute with `§§`, like `'..prefix..'add I like §§'..separator..'I like §§ more!`. Now every time someone wrote a sentence with `I like`, I would tell you I like that thing more than you.'
              },
              {
                name = prefix..'list',
                value = 'Get a list of all the triggers on this Server.'
              }
            }
          }
        }
      else
        message:reply{
          embed = {
            title = 'Hi. I\'m HopelessBot.',
            description = 'I can do various things, here\'s a list:',
            fields = {
              {
                name = 'Basic bot stuff',
                value = 'Use `'..prefix..'invite` to unleash me onto your server.'
              },
              {
                name = 'Triggers',
                value = 'You can define triggers and responses, and if a trigger is inside of a message, it responds what you defined.'
              }
            },
            footer = {text = 'Hint: '..prefix..'help <function> to get more detailed info.'}
          }
        }
      end
    elseif command.main == 'invite' then
      message:reply{
        embed = {
          title = 'Invite me to your Server!',
          description = 'Click [here](https://discordapp.com/oauth2/authorize?client_id=285707627684560898&scope=bot&permissions=0) to install every virus ever known.',
          footer = {
            text = 'Disclaimer: I do NOT guarantee that your users will stay on your server after you added me.'
          }
        }
      }
    end
  else
    if triggerTable[message.guild.id] then
      for key, value in pairs(triggerTable[message.guild.id]) do
        if message.content:find(value.trigger.pattern) then
          message:reply(value.response.pattern:format(message.content:match(value.trigger.pattern)))
        end
      end
    end

    for key, value in pairs(triggerTable.global) do
      if message.content:find(value.trigger.pattern) then
        message:reply(value.response.pattern:format(message.content:match(value.trigger.pattern)))
      end
    end
  end
end)

client:run(args[2])
