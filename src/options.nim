import npeg, os, strutils, tables, hashes
import x11 / [x, xlib]

const NimblePkgVersion {.strdefine.} = ""

let version = "Notifishower " & NimblePkgVersion
let doc = """
This is a simple program to display a combinations of text and images as a
notification on the screen. It does not read freedesktop notifications, for
that you might want to check out notificatcher.

Usage:
  notifishower [options]

Options:
  --help                                    Show this screen
  -v --version                              Show the version
  --config <file>                           Parses options from the config file
  --class <class>                           Set the window class [default: notishower]
  --name <name>                             Set the window name [default: Notishower]
  -x <x>                                    Set the x position of the notification [default: 0]
  -y <y>                                    Set the y position of the notification [default: 0]
  -w <w>                                    Set the width of the notification [default: 200]
  -h <h>                                    Set the height of the notification [default: 100]
  --background <color>                      Set the background colour of the notification
  --hover <color>                           Set the default colour of the hover indicator
  --border <color>                          Set the border colour of the notification
  --border.width <bw>                       Set the width of the border [default: 2]
  --font <font>                             Sets the default font for all text elements
  --action <action>                         Assign an action to clicks outside any element
  --ninepatch <path>                        Set the background to a ninepatch image
  --tile <bool>                             Set the ninepatch to tiling mode or not
  --shortcut <shortcut>                     Sets a keyboard shortcut for the default action
  --<id>.text <text>                        Store a text element with a given ID
  --<id>.font <font>                        Set the font for a text element
  --<id>.color <color>                      Set the color for a text element
  --<id>.image <path>                       Store an image element with a given ID
  --<id>.ninepatch <path>                   Set the background of an element to a ninepatch
  --<id>.tile <bool>                        Set the tiling mode of the background ninepatch
  --<id>.action <action>                    Assign an action to an element
  --<id>.hover <color>                      Set the color of the hover indicator
  --<id>.hover.ninepatch <path>             Set the hover indicator of an element to a ninepatch
  --<id>.hover.tile <bool>                  Set the tiling mode of the hover indicator ninepatch
  --<id>.shortcut <shortcut>                Adds a keyboard shortcut to run the element action
  --monitor <xrandrID> [<x>,<y>] [<w>:<h>]  Defines a monitor to show the notification on
  --format <format>                         Sets the layout of the notification
  --padding <number>                        The default padding for '-' in a pattern
  --timeout <number>                        Close the notification after a number of seconds

Positions and widths:
  X and Y positions can be the position on the monitor to display the
  notification, if you pass a negative number it will be placed that many pixels
  minus one away from the right or bottom. The minus one is because -0 isn't a
  valid number for the parser so -1 is the same as 0 pixels from the edge.
  Width and height are can also be negative, and it means screen width minus
  that amount. For width and height you're also able to define >= or <=
  constraints so -w >=100 would set the minimal size of the notification to
  100 but otherwise scale it larger.
  Border width is applied outside the window, so setting width to 100 and border
  width to 50 would still mean a 100 pixel area for the notification.

Colors:
  Colors are simple hex colors, with an optional # prefix. If a six character
  value is passed alpha is assumed to be FF, or if an eight character value is
  passed then the last two characters are considered the alpha value.

Ninepatch background:
  In order to be better able to customise the appearance of notifications
  notifishower also supports ninepatch background images. Ninepatches are normal
  images with a 1px border around the entire image, this border contains
  contiguous black pixels that signify which parts of the image can be
  stretched, and where to place content. When setting width and height of the
  notification it will be the width and height of the notification including the
  area required for padding in the ninepatch image, so your actual content area
  might be smaller. If you want the scaleable section to tile instead of stretch
  you can pass the --tile true option.
  Ninepatches can also be applied as background to any element. This is done by
  passing --<id>.ninepatch and similarily --<id>.tile. Unlike the global
  ninepatch background this draws the ninepatch outside the element so if you
  want to make sure it doesn't appear under other elements or collide with other
  backgrounds you need to supply your own padding in the format.

Fonts:
  Fonts are following the Imlib2 font format and are read from these folders:
    $HOME/.local/share/fonts
    $HOME/.fonts
    /usr/local/share/fonts
    /usr/share/fonts/truetype
    /usr/share/fonts/truetype/dejavu
    /usr/share/fonts/TTF
  The format is essentially the filename without the ".ttf" extension followed
  by a slash and the size, e.g. DejaVuSans/20 to load the file DejaVuSans.ttf
  from one of those folders at point 20 size.

Layout format:
  In order to give you the ultimate configuration ability notifishower
  implements a fairly simple visual formatting language. It features the
  following grammar elements:
    []      <- A group of vertical elements
    ()      <- A group of horizontal elements
    -       <- A bit of padding
    ~       <- An expanding bit of padding
    <label> <- An item that will be laid out
    :       <- The start of a constraint
  The default pattern is:
    (-[~icon:32~]-[~title body~]-)
  Which means a horizontal stack with padding before, after, and between two
  vertical sub-groups. The first sub-group contains the "icon" with expanding
  padding above and below (meaning it will be vertically centered). It also has
  a constrained size of 32 pixels in height (it will be scaled by aspect ratio
  to match). The second sub-group contains the "title" and "body" without
  padding between them and centered vertically in the group.
  The labels are defined by the --<id>.text and --<id>.image options.
  Constraints can be either a number or a number prefixed by ">=" or "<=" to
  specify if it's exact, or larger or greater than. It can also be a percentage
  postfixed by "%" which will be a percentage of the size of the containing
  group.
  To specify a width of a padding you can put a constraint in the middle of two
  "-" characters, for example '-10-', '->=20-', or '-5%-'.
  When using this format make sure that all your constraints are actually
  achievable, if not a notification will not be shown. Also make sure that you
  have sufficient expanding padding regions to take up any remaining space in
  the layout.

Clickable elements:
  Elements can be made clickable by assigned them an action. This is done by
  passing --<id>.action. When an element that has an action is clicked it will
  write the action to stdout and close the notification. When an element that
  has an action is hovered by the mouse it will paint a rectangle underneath
  itself in either the default hover color or the color defined with
  --<id>.hover. If you want to add a ninepatch image instead as the hover
  background you can use --<id>.hover.ninepatch and --<id>.hover.tile to
  specify the image and the tiling mode.

Shortcuts:
  Elements with an action can also be assigned a shortcut. You can pass
  --<id>.shortcut and a shortcut containing zero or more modifiers followed by a
  key name, separated by '+' symbols. For example 'ctrl+shift+b' or
  'XF86Search'. When the shortcut is pressed the action will be triggered the
  same way as if the element was clicked.
  The modifiers can be:
    ctrl
    shift
    lock
    mod1
    mod2
    mod3
    mod4
    mod5
  They can all be remapped in your X11 configuration, to see what they are
  bound to, you can run 'xmodmap -pm' to print the modifier map.

Monitors:
  By default a notification will be shown on all available monitors. If you
  want to define which monitors to show the notification on you can pass the
  --monitor parameter with an identifier from xrandr. If you specify one then
  you have to specify every monitor you want to display the notification on.
  You can also pass the position as x,y or the width as w:h following the same
  rule as the global parameters.

Configuration file:
  A configuration file is also supported. Is is essentially just a string
  transformation of the configuration file into the command line options. The
  format is simply options without the preceding dashes, followed by a colon,
  and the value as bash would parse it. This is how the default.conf file
  appears and contains all the default parameters:
    background: #444444
    border: #808080
    border.width: 2
    x: 49
    y: 0
    w: -98
    h: >=0
    font: DejaVuSans/10
    format: (-[~icon:32~]-[~title body~]-)
    title.font: DejaVuSans/12
    title.color: #FFFFFF
    body.color: #FFFFFF

Managing notifications:
  By default notifishower doesn't have any keyboard shortcuts to close the
  notification or any timeout method to remove them. In order to remove the
  notification you must kill the process, so it might be a good idea to add a
  "killall notifishower" shortcut to your window manager. It also doesn't
  support getting notifications from freedesktop, for that you might want to
  have a look at notificatcher.
"""

type
  Monitor* = object
    x*, y*, w*, h*: int
  Hover* = object
    action*: string
    color*: Color
    ninepatch*: string
    ninepatchTile*: bool
  Background* = object
    background*: Color
    ninepatch*: string
    ninepatchTile*: bool
  Shortcut* = object
    mask*: cuint
    key*: KeySym
  Text* = object
    text*: string
    font*: string
    color*: Color
  Image* = object
    image*: string
  Color* = object
    r*, g*, b*, a*: int
  Options* = object
    wopt*: string
    hopt*: string
    x*, y*, w*, h*: int
    background*, border*, hover*: Color
    borderWidth*: int
    ninepatch*: string
    ninepatchTile*: bool
    defaultFont*: string
    defaultAction*: string
    defaultShortcut*: Shortcut
    format*: string
    monitors*: Table[string, Monitor]
    text*: Table[string, Text]
    images*: Table[string, Image]
    hoverables*: Table[string, Hover]
    backgrounds*: Table[string, Background]
    shortcuts*: Table[Shortcut, string]
    name*, class*: string
    padding*: int
    timeout*: int

proc hash*(x: Shortcut): Hash =
  var h: Hash = 0
  h = h !& hash(x.mask)
  h = h !& hash(x.key.int)
  result = !$h

template monitorSetValues(i: int) =
  if capture[i+1].s == ",":
    monitor.x = parseInt capture[i].s
    monitor.y = parseInt capture[i+2].s
  else:
    monitor.w = parseInt capture[i].s
    monitor.h = parseInt capture[i+2].s

proc parseColor(color: string): Color =
  let s = if color[0] == '#': 1 else: 0
  result.r = parseHexInt(color[s..s+1])
  result.g = parseHexInt(color[s+2..s+3])
  result.b = parseHexInt(color[s+4..s+5])
  result.a = 255
  if color.len - s > 6:
    result.a = parseHexInt(color[s+6..s+7])

proc parseCommandFile*(file: string, defaults: var Options = default(Options)): Options

## TODO: Check that there is no collision between images and text
let parser = peg(input, options: Options):
  input <- option * *("\x1F" * option) * !1
  option <- help | version | position | size | background | hover | border | borderwidth | text | font | image | monitor | format | name | class | textColor | ninepatch | tile | config | padding | timeout | action | hoverNinepatch | hoverTile | shortcut
  help <- "--help":
    echo version & "\n"
    echo doc
    quit 0
  version <- ("--version" | "-v"):
    echo version
    quit 0
  monitor <- "--monitor\x1F" * >xrandrident * ?("\x1F" * >number * >',' * ?'\x1F' * >number) * ?("\x1F" * >number * >':' * ?'\x1F' * >number):
    var monitor = Monitor(x: int.high, y: int.high, w: int.high, h: int.high)
    if capture.len == 5:
      monitorSetValues(2)
    if capture.len == 8:
      monitorSetValues(2)
      monitorSetValues(5)
    options.monitors[$1] = monitor
  position <- "-" * >("x" | "y") * "\x1F" * >number:
    case $1:
    of "x": options.x = parseInt($2)
    of "y": options.y = parseInt($2)
  size <- "-" * >("w" | "h") * "\x1F" * >?comparator * >number:
    case $1:
    of "w":
      options.w = parseInt($3)
      options.wopt = $2
    of "h":
      options.h = parseInt($3)
      options.hopt = $2
  padding <- "--padding" * "\x1F" * >positiveNumber:
    options.padding = parseInt($1)
  ninepatch <- "--" * ?(>identifier * '.') * "ninepatch\x1F" * >string:
    if capture.len == 2: options.ninepatch = $1
    else: options.backgrounds.mgetOrPut($1, Background()).ninepatch = $2
  config <- "--config\x1F" * >string:
    options = parseCommandFile($1, options)
  tile <- "--" * ?(>identifier * '.') * "tile\x1F" * >boolean:
    if capture.len == 2: options.ninepatchTile = $1 == "true"
    else: options.backgrounds.mgetOrPut($1, Background()).ninepatchTile = $2 == "true"
  background <- "--" * ?(>identifier * '.') * "background\x1F" * >color:
    if capture.len == 2: options.background = parseColor($1)
    else: options.backgrounds.mgetOrPut($1, Background()).background = parseColor($2)
  hover <- "--" * ?(>identifier * '.') * "hover\x1F" * >color:
    if capture.len == 2: options.hover = parseColor($1)
    else: options.hoverables.mgetOrPut($1, Hover()).color = parseColor($2)
  hoverNinepatch <- "--" * >identifier * ".hover.ninepatch\x1F" * >string:
    options.hoverables.mgetOrPut($1, Hover()).ninepatch = $2
  shortcut <- "--" * ?(>identifier * '.') * "shortcut\x1F" * >shortcutPattern:
    var shortcut: Shortcut
    let
      shortcutPattern = if capture.len == 2: $1 else: $2
      pattern = shortcutPattern.split('+')
    shortcut.key = XStringToKeysym(pattern[^1])
    for modifier in pattern[0..^2]:
      shortcut.mask = shortcut.mask or (case modifier:
        of "ctrl": ControlMask
        of "shift": ShiftMask
        of "lock": LockMask
        of "mod1": Mod1Mask
        of "mod2": Mod2Mask
        of "mod3": Mod3Mask
        of "mod4": Mod4Mask
        of "mod5": Mod5Mask
        else: 0)
    if capture.len == 2: options.defaultShortcut = shortcut
    else: options.shortcuts[shortcut] = $1
  hoverTile <- "--" * >identifier * ".hover.tile\x1F" * >boolean:
    options.hoverables.mgetOrPut($1, Hover()).ninepatchTile = $2 == "true"
  border <- "--border\x1F" * >color:
    options.border = parseColor($1)
  borderwidth <- "--border.width\x1F" * >positiveNumber:
    options.borderWidth = parseInt($1)
  text <- "--" * >identifier * ".text\x1F" * >string:
    options.text.mgetOrPut($1, Text()).text = $2
  textColor <- "--" * >identifier * ".color\x1F" * >color:
    options.text.mgetOrPut($1, Text()).color = parseColor($2)
  image <- "--" * >identifier * ".image\x1F" * >string:
    options.images.mgetOrPut($1, Image()).image = $2
  font <- "--" * ?(>identifier * '.') * "font\x1F" * >fontidentifier:
    if capture.len == 2: options.defaultFont = $1
    else: options.text.mgetOrPut($1, Text()).font = $2
  action <- "--" * ?(>identifier * ".") * "action\x1F" * >string:
    if capture.len == 2: options.defaultAction = $1
    else: options.hoverables.mgetOrPut($1, Hover()).action = $2
  format <- "--format\x1F" * >string:
    options.format = $1
  timeout <- "--timeout\x1F" * >positiveNumber:
    options.timeout = parseInt($1)
  name <- "--name\x1F" * >string:
    options.name = $1
  class <- "--class\x1F" * >string:
    options.class = $1
  comparator <- ">=" | "<="
  number <- (?'-' * {'1'..'9'} * *Digit) | '0'
  positiveNumber <- ({'1'..'9'} * *Digit) | '0'
  identifier <- Alpha * *(Alnum | '_')
  string <- *Print
  boolean <- "true" | "false"
  modifiers <- "ctrl" | "shift" | "lock" | "mod1" | "mod2" | "mod3" | "mod4" | "mod5"
  shortcutPattern <- *(modifiers * '+') * string
  #string <- (+UnquotStrChar) | ('"' * *StrChar * '"')
  #UnquotStrChar <- {'!', 0x23..0x7E}
  #StrChar <- {'\t', ' ', '!', 0x23..0x7E}
  xrandrident <- +Print #UnquotStrChar
  color <- ?'#' * (Xdigit[8] | Xdigit[6])
  fontidentifier <- +nonslash * +(('/' * positiveNumber * &('\x1F' | !1)) | ('/' * +nonslash * &1 * &(!'\x1F')))
  nonslash <- {0x21..0x2E, 0x30..0x7E}

proc parseCommandLine*(defaults: var Options = default(Options), opts = commandLineParams()): Options =
  result = defaults
  let params = opts.join("\x1F")
  let match = parser.match(params, result)
  if not match.ok:
    echo "Unable to parse options:"
    echo params.replace("\x1F", " ")
    echo " ".repeat(match.matchMax) & "^"
    quit 1

proc parseCommandFile*(file: string, defaults: var Options = default(Options)): Options =
  var options: seq[string]
  for line in file.lines:
    if line.strip[0] != '#':
      let split = line.split(":", maxSplit = 1)
      options.add "-".repeat(min(2, split[0].len)) & split[0]
      options.add split[1].strip
  parseCommandLine(defaults, options)
