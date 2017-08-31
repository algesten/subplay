parser     = require 'subtitles-parser'

merge   = (t, os...) -> t[k] = v for k,v of o when v != undefined for o in os; t

isstring = (t) -> typeof t == 'string'
isfunc   = (t) -> typeof t == 'function'

DEFAULT_OPTS = {
  millis: false   # default is to interpret time as seconds with fraction
}

# calculate the distance to an entry. returns undefined if
# we've passed the entry's endTime
distance = (ms, e) ->
  if !e?.endTime? or ms > e?.endTime then undefined else e.endTime - ms

# locate the current or next entry in the data array. pos is a suggested
# position
locate = (data, ms, pos, checkPrev = true) ->
  if pos == undefined
    # we might be past the last entry's endTime, let's make sure
    [..., last] = data
    if distance ms, last == undefined
      return undefined # indeed we are, so don't bother locating
    else
      pos = 0 # start over
      checkPrev = false
  cur = data[pos]
  curd = distance ms, cur
  if checkPrev and curd?
    pre = data[pos - 1]
    pred = distance ms, pre
    # if the distance of previous entry is better
    # than the current, we must have skipped back in time
    # this results in a full scan from the beginning
    return locate data, ms, 0, false if pred? and pred < curd
  # check if next entry's distance is better than the one
  # we're at, in which case we move on.
  if !curd? and (pos + 1) >= data.length then return undefined # we are past the last entry
  nxt = data[pos + 1]
  nxtd = distance ms, nxt
  if !curd? or nxtd < curd then locate(data, ms, pos + 1, false) else pos


sub = (srt, renderer, opts = {}) ->
  throw new Error("Bad srt") unless isstring srt
  throw new Error("Bad renderer") unless isfunc renderer
  opts = merge {}, DEFAULT_OPTS, opts

  #  [..., { id: '587',
  #    startTime: 2963463,
  #    endTime: 2966132,
  #    text: 'Long, sullen silences' }, ...]
  data = parser.fromSrt srt, true

  pos = 0        # position in data array
  current = null # the currently showing entry (if any)
  timeout = null # timeout to fire the next renderer
  lastExtern = 0 # the last time we got an external update

  # the update function returned to caller
  update = (time, inmillis = opts.millis, selftrig = false, isplaying = true) ->

    ms = if inmillis then time else time * 1000

    pos = locate data, ms, pos # locate returns current or next position
    entry = data[pos]

    # remember current time
    t = Date.now()

    # update timestamp we got external update (unless self triggered)
    lastExtern = t unless selftrig

    # call renderer after wait time with entry.
    render = (wait, text, entry) ->
      if !isplaying and wait > 0 then return # video is on pause - time is not running, no point in setting a timeout
      timeout = setTimeout ->
        # insert a sneaky '' if we got a render for next event before
        # the clearing of the previous
        renderer('') if current != null and entry != null
        # render this text
        renderer(text)
        current = entry
        # schedule next event, but only keep this up 5 sec
        # after last external update
        if (Date.now() - lastExtern) < 5000
            update ms + (Date.now() - t) + 5, true, true
      , wait

    # every time we get an update, we cancel the current timer
    # since the time code for the video may not be exactly
    # that of setTimeout()
    clearTimeout timeout if timeout

    if ms < 0
      # negative time means we stop doing the rendering
      return
    else if pos == undefined # we are past the last entry
      render 0, '', null
    else if ms < entry.startTime
      if entry != current
        # remove current if there is any (there shouldn't be)
        if current
          render 0, '', null
        # schedule a future render entry
        render entry.startTime - ms, entry.text, entry
    else if ms < entry.endTime
      # we're before the current entry's end time,
      if current == entry
        # schedule a clear.
        render entry.endTime - ms, '', null
      else
        # render current entry right now
        render 0, entry.text, entry


module.exports = sub
