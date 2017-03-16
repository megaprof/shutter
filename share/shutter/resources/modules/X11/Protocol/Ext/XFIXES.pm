# Copyright 2011, 2012, 2013, 2014 Kevin Ryde

# This file is part of X11-Protocol-Other.
#
# X11-Protocol-Other is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# X11-Protocol-Other is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with X11-Protocol-Other.  If not, see <http://www.gnu.org/licenses/>.

BEGIN { require 5 }
package X11::Protocol::Ext::XFIXES;
use X11::Protocol 'padded';
use strict;
use Carp;

use vars '$VERSION', '@CARP_NOT';
$VERSION = 29;
@CARP_NOT = ('X11::Protocol');

# uncomment this to run the ### lines
# use Smart::Comments;

# /usr/share/doc/x11proto-fixes-dev/fixesproto.txt.gz
#     http://cgit.freedesktop.org/xorg/proto/fixesproto/tree/fixesproto.txt
# /usr/include/X11/extensions/xfixesproto.h
# /usr/include/X11/extensions/xfixeswire.h
#
# /usr/share/doc/x11proto-xext-dev/shape.txt.gz
#
# /usr/include/X11/extensions/Xfixes.h
#     Xlib.
#
# /usr/share/doc/x11proto-core-dev/x11protocol.txt.gz


# these not documented yet ...
use constant CLIENT_MAJOR_VERSION => 5;
use constant CLIENT_MINOR_VERSION => 0;


#------------------------------------------------------------------------------
# symbolic constants

use constant constants_list =>
  (XFixesWindowRegionKind => ['Bounding', 'Clip'],
   XFixesSaveSetMode      => ['Insert', 'Delete'],
   XFixesSaveSetTarget    => ['Nearest', 'Root'],
   XFixesSaveSetMap       => ['Map', 'Unmap'],

   XFixesSelectionNotifySubtype => [ 'SetSelectionOwner',
                                     'SelectionWindowDestroy',
                                     'SelectionClientClose' ],
   XFixesCursorNotifySubtype => [ 'DisplayCursor' ],

   # Not sure about these two ...
   # XFixesSelectionEventMask => [ 'SetSelectionOwner',
   #                               'SelectionWindowDestroy',
   #                               'SelectionClientClose' ],
   # XFixesCursorEventMask     => [ 'DisplayCursor' ],
  );

sub _ext_constants_install {
  my ($X, $constants_arrayref) = @_;
  foreach (my $i = 0; $i <= $#$constants_arrayref; $i+=2) {
    my $name = $constants_arrayref->[$i];
    my $aref = $constants_arrayref->[$i+1];
    $X->{'ext_const'}->{$name} = $aref;
    $X->{'ext_const_num'}->{$name} = { X11::Protocol::make_num_hash($aref) };
  }
}

#------------------------------------------------------------------------------
# events

my $events_arrayref
  = [ XFixesSelectionNotify =>
      [ 'xCxxL5',
        ['subtype','XFixesSelectionNotifySubtype'],
        'window',
        ['owner',['None']], # window
        'selection',        # atom
        'time',
        'selection_time',
      ],

      XFixesCursorNotify =>
      [ sub {
          my $X = shift;
          my $data = shift;
          ### XFixesCursorNotify unpack: @_
          my ($subtype, $window, $cursor_serial, $time, $cursor_name)
            = unpack 'xCxxL4', $data;
          return (@_,  # base fields
                  subtype => $X->interp('XFixesCursorNotifySubtype',$subtype),
                  window  => _interp_none($X,$window), # probably not None though
                  cursor_serial => $cursor_serial,
                  time    => _interp_time($time),
                  # "name" field only in XFIXES 2.0 up, probably pad garbage
                  # in 1.0, so omit there.  Give it as "cursor_name" since
                  # plain "name" is the event name.
                  ($X->{'ext'}->{'XFIXES'}->[3]->{'major'} >= 2
                   ? (cursor_name => $cursor_name)
                   : ()));
        },
        sub {
          my ($X, %h) = @_;
          # "cursor_name" can be omitted as for a 1.0 event
          return (pack('xCxxL4x12',
                       $X->num('XFixesCursorNotifySubtype',$h{'subtype'}),
                       _num_none($h{'window'}),
                       $h{'cursor_serial'},
                       _num_time($h{'time'}),
                       _num_none($h{'cursor_name'} || 0)),
                  1); # "do_seq" put in sequence number
        } ],
    ];

sub _ext_events_install {
  my ($X, $event_num, $events_arrayref) = @_;
  foreach (my $i = 0; $i <= $#$events_arrayref; $i+=2) {
    my $name = $events_arrayref->[$i];
    if (defined (my $already = $X->{'ext_const'}->{'Events'}->[$event_num])) {
      carp "Event $event_num $already overwritten with $name";
    }
    $X->{'ext_const'}->{'Events'}->[$event_num] = $name;
    $X->{'ext_events'}->[$event_num] = $events_arrayref->[$i+1]; # pack/unpack
    $event_num++;
  }
}

#------------------------------------------------------------------------------
# requests

my $requests_arrayref =
  [
   [ 'XFixesQueryVersion',  # 0
     sub {
       my ($X, $major, $minor) = @_;
       ### XFixesQueryVersion request
       return pack 'LL', $major, $minor;
     },
     sub {
       my ($X, $data) = @_;
       ### XFixesQueryVersion reply: "$X"
       my @ret = unpack 'x8SS', $data;
       my $self;
       if ($self = $X->{'ext'}->{'XFIXES'}->[3]) {
         ($self->{'major'},$self->{'minor'}) = @ret;
       }
       return @ret;
     }],

   [ 'XFixesChangeSaveSet',  # 1
     sub {
       my ($X, $window, $mode, $target, $map) = @_;
       return pack ('CCCxL',
                    $X->num('XFixesSaveSetMode',$mode),
                    $X->num('XFixesSaveSetTarget',$target),
                    $X->num('XFixesSaveSetMap',$map),
                    $window);
     }],

   [ 'XFixesSelectSelectionInput',  # 2
     # ($X, $window, $selection, $event_mask)
     # nothing special for $event_mask yet
     \&_request_card32s ],

   [ 'XFixesSelectCursorInput',  # 3
     # ($X, $window, $event_mask) nothing special for $event_mask yet
     \&_request_card32s ],

   [ 'XFixesGetCursorImage',  # 4
     \&_request_empty,
     sub {
       my ($X, $data) = @_;
       # (rootx,rooty, width,height, xhot,yhot, serial, ... then pixels)
       my @ret = unpack 'x8ssSSSSL', $data;
       return (@ret,
               substr ($data, 32, 4*$ret[2]*$ret[3])); # width*height
     }],

   #---------------------------------------------------------------------------
   # version 2.0

   [ 'XFixesCreateRegion',   # 5
     \&_request_region_and_rectangles ],

   [ 'XFixesCreateRegionFromBitmap',   # 6
     \&_request_xids ],

   [ 'XFixesCreateRegionFromWindow',   # 7
     sub {
       my ($X, $region, $window, $kind) = @_;
       ### XFixesCreateRegionFromWindow: $region, $window, $kind
       return pack ('LLCxxx',
                    $region,
                    $window,
                    $X->num('XFixesWindowRegionKind',$kind));
     }],

   [ 'XFixesCreateRegionFromGC',   # 8
     \&_request_xids ],

   [ 'XFixesCreateRegionFromPicture',   # 9
     \&_request_xids ],

   [ 'XFixesDestroyRegion',   # 10
     \&_request_xids ],

   [ 'XFixesSetRegion',   # 11
     \&_request_region_and_rectangles ],

   [ 'XFixesCopyRegion',   #    12
     \&_request_xids ],

   [ 'XFixesUnionRegion',   # 13
     \&_request_xids ],
   [ 'XFixesIntersectRegion',   # 14
     \&_request_xids ],
   [ 'XFixesSubtractRegion',   # 15
     \&_request_xids ],

   [ 'XFixesInvertRegion',   # 16
     sub {
       my ($X, $src, $rect, $dst) = @_;
       return pack 'LssSSL', $src, @$rect, $dst;
     }],

   [ 'XFixesTranslateRegion',   # 17
     sub {
       shift; # ($X, $region, $dx, $dy)
       return pack 'Lss', @_;
     }],

   [ 'XFixesRegionExtents',   # 18
     \&_request_card32s ], # ($X, $src, $dst)

   [ 'XFixesFetchRegion',   # 19
     \&_request_card32s, # ($X, $region)
     sub {
       my ($X, $data) = @_;
       ### XFixesFetchRegion reply: length($data)
       my @ret = ([ unpack 'x8ssSS', $data ]);  # bounding
       for (my $pos = 32; $pos < length($data); $pos+=8) {
         push @ret, [ unpack 'ssSS', substr($data,$pos,8) ];
       }
       return @ret;
     }],

   [ 'XFixesSetGCClipRegion',   # 20
     \&_request_xid_xy_region], # ($gc, $x, $y, $region)

   [ 'XFixesSetWindowShapeRegion',   # 21
     sub {
       my ($X, $window, $shape_kind, $x, $y, $region) = @_;
       # use ShapeKind if SHAPE initialized, otherwise same Bounding and
       # Clip from XFixesWindowRegionKind
       my $kind_type = ($X->{'ext_const'}->{'ShapeKind'}
                        ? 'ShapeKind' : 'XFixesWindowRegionKind');
       return pack ('LCxxxssL',
                    $window,
                    $X->num($kind_type,$shape_kind),
                    $x,$y,
                    _num_none ($region));
     }],

   [ 'XFixesSetPictureClipRegion',   # 22
     \&_request_xid_xy_region ],  # ($pict, $x, $y, $region)

   [ 'XFixesSetCursorName',   # 23
     sub {
       my ($X, $cursor, $str) = @_;
       ### XFixesSetCursorName request
       ### $cursor
       ### $str
       return pack('LSxx'.padded($str),
                   $cursor, length($str), $str);
     }],

   [ 'XFixesGetCursorName',   # 24
     \&_request_xids,
     sub {
       my ($X, $data) = @_;
       ### XFixesGetCursorName reply
       my ($atom, $len) = unpack 'x8LS', $data;
       return (_interp_none($X,$atom), substr($data,32,$len));
     }],

   [ 'XFixesGetCursorImageAndName',   # 25
     \&_request_empty,
     sub {
       my ($X, $data) = @_;
       # (x,y, w,h, xhot,yhot, serial, atom, $namelen, ... then pixels+name)
       my @ret = unpack 'x8ssSSSSLLSxx', $data;
       my $namelen = pop @ret;
       my $atom = pop @ret;
       my $pixelsize = 4 * $ret[2] * $ret[3];
       return (@ret,
               substr ($data, 32, $pixelsize),              # pixels
               _interp_none($X,$atom),
               substr ($data, 32 + $pixelsize, $namelen));  # name
     }],

   [ 'XFixesChangeCursor',   # 26
     sub {
       my ($X, $src, $dst) = @_;
       return pack 'LL', $src, $dst;
     }],

   [ 'XFixesChangeCursorByName',   # 27
     sub {
       my ($X, $src, $str) = @_;
       return pack ('LSxx'.padded($str),
                    $src, length($str), $str);
     }],


   #---------------------------------------------------------------------------
   # version 3.0

   [ 'XFixesExpandRegion',  # 28
     sub {
       shift; # $X
       return pack 'LLSSSS', @_; # $src, $dst, $left,$right, $top,$bottom
     }],


   #---------------------------------------------------------------------------
   # version 4.0

   ['XFixesHideCursor',  # 29
    \&_request_xids ],
   ['XFixesShowCursor',  # 30
    \&_request_xids ],

   #---------------------------------------------------------------------------
   # version 5.0

   ['XFixesCreatePointerBarrier',  # 31
    sub {
      my ($X, $barrier, $drawable, $x1,$y1, $x2,$y2, $directions,
          @devices) = @_;
      my $devices = pack 'S*', map{_num_xinputdevice($_)} @devices;
      ### @devices
      ### $devices
      ### format: 'LLssssLxxS'.padded($devices)
      return pack ('LLssssLxxS'.padded($devices),
                   $barrier,             # CARD32
                   $drawable,            # CARD32
                   $x1,$y1, $x2,$y2,     # INT16 x 4
                   $directions,          # CARD32
                   scalar(@devices),     # CARD16 num_devices
                   $devices);            # packed CARD16s
    }],

   ['XFixesDestroyPointerBarrier',  # 32
    \&_request_xids ],  # ($X, $barrier)  single barrier to destroy
  ];

sub _ext_requests_install {
  my ($X, $request_num, $requests_arrayref) = @_;

  $X->{'ext_request'}->{$request_num} = $requests_arrayref;
  my $href = $X->{'ext_request_num'};
  my $i;
  foreach $i (0 .. $#$requests_arrayref) {
    $href->{$requests_arrayref->[$i]->[0]} = [$request_num, $i];
  }
}

#------------------------------------------------------------------------------

sub new {
  my ($class, $X, $request_num, $event_num, $error_num) = @_;
  ### XFIXES new()

  my $self = bless { }, $class;
  _ext_constants_install ($X, [ $self->constants_list ]);
  _ext_requests_install ($X, $request_num, $requests_arrayref);
  _ext_events_install ($X, $event_num, $events_arrayref);

  # the protocol spec says must query version with what we support
  # need it to know which error types are defined too, as otherwise oughtn't
  # touch anything at $event_num
  my ($server_major, $server_minor)
    = $X->req ('XFixesQueryVersion',
               CLIENT_MAJOR_VERSION, CLIENT_MINOR_VERSION);
  $self->{'major'} = $server_major;
  $self->{'minor'} = $server_minor;

  # Errors
  _ext_error_install ($X, $error_num,
                      # version 2.0
                      ($server_major >= 2 ? ('Region') : ()),
                      # version 5.0
                      ($server_major >= 5 ? ('Barrier') : ()));

  return $self;
}

sub _request_empty {
  if (@_ > 1) {
    croak "No parameters in this request";
  }
  return '';
}

sub _request_xids {
  my $X = shift;
  ### _request_xids(): @_
  return _request_card32s ($X, map {_num_none($_)} @_);
}
sub _request_card32s {
  shift;
  ### _request_card32s(): @_
  return pack 'L*', @_;
}

sub _request_xid_xy_region {
  my ($X, $xid, $x, $y, $region) = @_;
  return pack ('LLss', $xid, _num_none($region), $x,$y);
}

sub _request_region_and_rectangles {
  shift; # $X
  ### _request_region_and_rectangles: @_
  my $region = shift;
  ### ret: pack('L',$region) . _pack_rectangles(@_)
  return pack('L',$region) . _pack_rectangles(@_);
}
sub _pack_rectangles {
  return join ('', map {pack 'ssSS', @$_} @_);
}

sub _num_none {
  my ($xid) = @_;
  if (defined $xid && $xid eq 'None') {
    return 0;
  } else {
    return $xid;
  }
}
sub _interp_none {
  my ($X, $xid) = @_;
  if ($X->{'do_interp'} && $xid == 0) {
    return 'None';
  } else {
    return $xid;
  }
}

sub _interp_time {
  my ($time) = @_;
  if ($time == 0) {
    return 'CurrentTime';
  } else {
    return $time;
  }
}
sub _num_time {
  my ($time) = @_;
  if ($time eq 'CurrentTime') {
    return 0;
  } else {
    return $time;
  }
}


sub _num_xinputdevice {
  my ($device) = @_;
  if ($device eq 'AllDevices')       { return 0; }
  if ($device eq 'AllMasterDevices') { return 1; }
  return $device;
}

sub _ext_error_install {
  my $X = shift;  # ($X, $errname1,$errname2,...)
  ### _ext_error_install: @_
  my $error_num = shift;
  my $aref = $X->{'ext_const'}{'Error'}  # copy
    = [ @{$X->{'ext_const'}{'Error'} || []} ];
  my $href = $X->{'ext_const_num'}{'Error'}  # copy
    = { %{$X->{'ext_const_num'}{'Error'} || {}} };
  my $i;
  foreach $i (0 .. $#_) {
    $aref->[$error_num + $i] = $_[$i];
    $href->{$_[$i]} = $error_num + $i;
  }
}

1;
__END__

=for stopwords XFIXES XID reparent Unmap arrayref AARRGGBB GG pre-multiplied pixmap RENDER ShapeKind subwindow Ryde hotspot ARGB GC ie latin-1 DisplayCursor RGB bitmask XIDs YX-banded subtypes XTEST Xvfb xdm Xlib Xinerama subtype

=head1 NAME

X11::Protocol::Ext::XFIXES - miscellaneous "fixes" extension

=head1 SYNOPSIS

 use X11::Protocol;
 my $X = X11::Protocol->new;
 $X->init_extension('XFIXES')
   or print "XFIXES extension not available";

=head1 DESCRIPTION

The XFIXES extension adds some features which are conceived as "fixing"
omissions in the core X11 protocol, including

=over

=item *

Events for changes to the selection (the cut and paste between clients).

=item *

Current cursor image fetching, cursor change events, and cursor naming and
hiding.

=item *

Server-side "region" objects representing a set of rectangles.

=back

=head1 REQUESTS

The following are made available with an C<init_extension()> per
L<X11::Protocol/EXTENSIONS>.

    my $bool = $X->init_extension('XFIXES');

=head2 XFIXES version 1.0

=over

=item C<($server_major, $server_minor) = $X-E<gt>XFixesQueryVersion ($client_major, $client_minor)>

Negotiate a protocol version with the server.  C<$client_major> and
C<$client_minor> is what the client would like, the returned
C<$server_major> and C<$server_minor> is what the server will do, which
might be less than requested (but not more than).

The current code in this module supports up to 4.0 and automatically
negotiates within C<init_extension()>, so direct use of
C<XFixesQueryVersion()> is not necessary.  Asking for higher than the code
supports might be a bad idea.

=item C<($atom, $str) = $X-E<gt>XFixesChangeSaveSet ($window, $mode, $target, $map)>

Insert or delete C<$window> (an XID) from the "save set" of resources to be
retained on the server when the client disconnects.  This is an extended
version of the core C<ChangeSaveSet()> request.

C<$mode> is either "Insert" or "Delete".

C<$target> is how to reparent C<$window> on client close-down, either
"Nearest" or "Root".  The core C<ChangeSaveSet()> is "Nearest" and means go
to the next non-client ancestor window.  "Root" means go to the root window.

C<$map> is either "Map" or "Unmap" to apply to C<$window> on close-down.
The core C<ChangeSaveSet()> is "Map".

=item $X-E<gt>XFixesSelectSelectionInput ($window, $selection, $event_mask)>

Select C<XFixesSelectionNotify> events (see L</"EVENTS"> below) to be sent
to C<$window> when C<$selection> (an atom) changes.

    $X->XFixesSelectSelectionInput ($my_window,
                                    $X->atom('PRIMARY'),
                                    0x07);

C<$window> is given in the resulting C<XFixesSelectionNotify>.  It probably
works to make it just a root window.  Selections are global to the whole
server, so the window doesn't implicitly choose a screen or anything.

C<$event_mask> has three bits for which event subtypes should be reported.

                            bitpos  bitval
    SetSelectionOwner         0      0x01
    SelectionWindowDestroy    1      0x02
    SelectionClientClose      2      0x04

There's no pack function for these yet so just give an integer, for instance
0x07 for all three.

See F<examples/xfixes-selection.pl> for a sample program listening to
selection changes with this request.

=item $X-E<gt>XFixesSelectCursorInput ($window, $event_mask)>

Select C<XFixesCursorNotify> events (see L</"EVENTS"> below) to be sent to
the client.

C<$window> is given in the resulting C<XFixesSelectionNotify>.  It probably
works to make it just a root window.  The cursor image is global and the
events are for any change, not merely within C<$window>.

C<$event_mask> has only a single bit, asking for displayed cursor changes,

                     bitpos  bitval
    DisplayCursor      0      0x01

There's no pack function for this yet, just give integer 1 or 0.

=item ($root_x,$root_y, $width,$height, $xhot,$yhot, $serial, $pixels) = $X-E<gt>XFixesGetCursorImage ()>

Return the size and pixel contents of the currently displayed mouse pointer
cursor.

C<$root_x>,C<$root_y> is the pointer location in root window coordinates
(similar to C<QueryPointer()>).

C<$width>,C<$height> is the size of the cursor image.  C<$xhot>,C<$yhot> is
the "hotspot" position within that, which is the pixel that follows the
pointer location.

C<$pixels> is a byte string of packed "ARGB" pixel values.  Each is 32-bits
in client byte order, with C<$width> many in each row and C<$height> such
rows and no padding in between, so a total C<4*$width*$height> bytes.  This
can be unpacked with for instance

    my @argb = unpack 'L*', $pixels; # each 0xAARRGGBB

    # top left pixel is in $argb[0]
    my $alpha = ($argb[0] >> 24) & 0xFF;  # each value
    my $red   = ($argb[0] >> 16) & 0xFF;  # 0 to 255
    my $green = ($argb[0] >> 8)  & 0xFF;
    my $blue  =  $argb[0]        & 0xFF;

The alpha transparency is pre-multiplied into the RGB components, so if the
alpha is zero (transparent) then the components are zero too.

The core C<CreateCursor()> bitmask always makes alpha=0 transparent or
alpha=255 opaque pixels.  The RENDER extension (see
L<X11::Protocol::Ext::RENDER>) can make partially transparent cursors.

There's no direct way to get the image of a cursor by its XID (except
something dodgy like a C<GrabPointer()> to make it the displayed cursor).
Usually cursor XIDs are only ever created by a client itself so no need to
read back (and the cursor XID can't be read out of an arbitrary window --
though the XTEST extension can do some comparing, per
L<X11::Protocol::Ext::XTEST>).

For reference, in the X.org server circa version 1.11, the server may start
up with no cursor at all, and when that happens an attempt to
C<XFixesGetCursorImage()> gives a "Cursor" error.  In practice this probably
only happens using a bare Xvfb or similar, since in normal use xdm or the
window manager will almost certainly have set a cursor.

See F<examples/xfixes-cursor-image.pl> in the X11-Protocol-Other sources for
a sample program getting the cursor image with this request.

=back

=head2 XFIXES version 2.0

A region object on the server represents a set of rectangles, each
x,y,width,height, with positive or negative x,y, and the set possibly made
of disconnected sections, etc.  (Basically a server-side copy of the Xlib
region code, see L<XCreateRegion(3)>.)

Each rectangle might be just 1x1 for a single pixel, so a region can
represent any bitmap, but it's geared towards the sort of rectangle
arithmetic which arises from overlapping rectangular windows etc.

=over

=item C<$X-E<gt>XFixesCreateRegion ($region, $rect...)>

Create C<$region> (a new XID) as a region and set it to the union of the
given rectangles, or empty if none.  Each C<$rect> is an arrayref
C<[$x,$y,$width,$height]>.

    my $region = $X->new_rsrc;
    $X->XFixesCreateRegion ($region, [0,0,10,5], [100,100,1,1]);

=item C<$X-E<gt>XFixesCreateRegionFromBitmap ($region, $bitmap)>

Create a region initialized from the 1 bits of C<$bitmap> (a pixmap XID).

    my $region = $X->new_rsrc;
    $X->XFixesCreateRegionFromBitmap ($region, $bitmap);

=item C<$X-E<gt>XFixesCreateRegionFromWindow ($region, $window, $kind)>

Create a region initialized from the shape of C<$window> (an XID).  C<$kind>
is either "Bounding" or "Clip" as per the SHAPE extension (see
L<X11::Protocol::Ext::SHAPE>).

    my $region = $X->new_rsrc;
    $X->XFixesCreateRegionFromBitmap ($region, $window, 'Clip');

There's no need to C<$X-E<gt>init_extension('SHAPE')> before using this
request.  Any shape is just on the server and results in a C<$region> of
either a single rectangle or set of rectangles for a shape.

=item C<$X-E<gt>XFixesCreateRegionFromGC ($region, $gc)>

Create a region initialized from the clip mask of C<$gc> (an XID).

    my $region = $X->new_rsrc;
    $X->XFixesCreateRegionFromGC ($region, $gc);

The region is relative to the GC C<clip_x_origin> and C<clip_y_origin>,
ie. those offsets are not applied to the X,Y in the region.

=item C<$X-E<gt>XFixesCreateRegionFromPicture ($region, $picture)>

Create a region initialized from a RENDER C<$picture> (an XID).

    my $region = $X->new_rsrc;
    $X->XFixesCreateRegionFromBitmap ($region, $picture);

The region is relative to the picture C<clip_x_origin> and C<clip_y_origin>,
ie. those offsets are not applied to the X,Y in the region.

Picture objects are from the RENDER extension (see
L<X11::Protocol::Ext::RENDER>).  This request always exists, but is not
useful without RENDER.

=item C<$X-E<gt>XFixesDestroyRegion ($region)>

Destroy C<$region>.

=item C<$X-E<gt>XFixesSetRegion ($region, $rect...)>

Set C<$region> to the union of the given rectangles, or empty if none.  Each
C<$rect> is an arrayref C<[$x,$y,$width,$height]>, as per
C<XFixesCreateRegion()> above.

    $X->XFixesSetRegion ($region, [0,0,20,10], [100,100,5,5])

=item C<$X-E<gt>XFixesCopyRegion ($dst, $src)>

Copy a region C<$src> to region C<$dst>.

=item C<$X-E<gt>XFixesUnionRegion ($src1, $src2, $dst)>

=item C<$X-E<gt>XFixesIntersectRegion ($src1, $src2, $dst)>

=item C<$X-E<gt>XFixesSubtractRegion ($src1, $src2, $dst)>

Set region C<$dst> to respectively the union or intersection of C<$src1> and
C<$src2>, or the subtraction C<$src1> - C<$src2>.

C<$dst> can be one of the source regions if desired, to change in-place.

=item C<$X-E<gt>XFixesInvertRegion ($src, $rect, $dst)>

Set region C<$dst> to the inverse of C<$src> bounded by rectangle C<$rect>,
ie. C<$rect> subtract C<$src>.  C<$rect> is an arrayref
C<[$x,$y,$width,$height]>.

    $X-XFixesInvertRegion ($src, [10,10, 200,100], $dst)>

C<$dst> can be the same as C<$src> to do an "in-place" invert.

=item C<$X-E<gt>XFixesTranslateRegion ($region, $dx, $dy)>

Move the area covered by C<$region> by an offset C<$dx> and C<$dy>
(integers).

=item C<$X-E<gt>XFixesRegionExtents ($dst, $src)>

Set region C<$dst> to the rectangular bounds of region C<$src>.  If C<$src>
is empty then C<$dst> is set to empty.

=item C<($bounding, @parts) = $X-E<gt>XFixesFetchRegion ($region)>

Return the rectangles which cover C<$region>.  Each returned element is an
arrayref

    [$x,$y,$width,$height]

The first is a bounding rectangle, and after that the individual rectangles
making up the region, in "YX-banded" order.

    my ($bounding, @rects) = $X->XFixesFetchRegion ($region);
    print "bounded by ",join(',',@$bounding);
    foreach my $rect (@rects) {
      print "  rect part ",join(',',@$rect);
    }

=item C<$X-E<gt>XFixesSetGCClipRegion ($gc, $clip_x_origin, $clip_y_origin, $region)>

Set the clip mask of C<$gc> (an XID) to C<$region> (an XID), and set the
clip origin to C<$clip_x_origin>,C<$clip_x_origin>.

This is similar to the core C<SetClipRectangles()>, but the rectangles are
from C<$region> (and no "ordering" parameter).

=item C<$X-E<gt>XFixesSetWindowShapeRegion ($window, $kind, $x_offset, $y_offset, $region)>

Set the shape mask of C<$window> (an XID) to C<$region>, at offset
C<$x_offset>,C<$y_offset> into the window.  C<$kind> is a ShapeKind, either
"Bounding" or "Clip".

This is similar to C<ShapeMask()> (see L<X11::Protocol::Ext::SHAPE>) with
operation "Set" and a a region instead of a bitmap.

It's not necessary to C<$X-E<gt>init_extension('SHAPE')> before using this
request.  If SHAPE is not available on the server then presumably this
request gives an error reply.

=item C<$X-E<gt>XFixesSetPictureClipRegion ($picture, $clip_x_origin, $clip_y_origin, $region)>

Set the clip mask of RENDER C<$picture> (an XID) to C<$region>, and set the
clip origin to C<$clip_x_origin>,C<$clip_x_origin>.

This is similar to C<RenderSetPictureClipRectangles()>, but the rectangles
are from C<$region>.

Picture objects are from the RENDER extension (see
L<X11::Protocol::Ext::RENDER>).  The request always exists, but is not useful
without RENDER.

=item C<$X-E<gt>XFixesSetCursorName ($cursor, $str)>

Set a name for cursor object C<$cursor> (an XID).  The name string C<$str>
is interned as an atom in the server and therefore should consist only of
latin-1 characters.  (Perhaps in the future that might be enforced here, or
wide chars converted.)

=item C<($atom, $str) = $X-E<gt>XFixesGetCursorName ($cursor)>

Get the name of mouse pointer cursor C<$cursor> (an XID), as set by
C<XFixesSetCursorName()>.

The returned C<$atom> is the name atom (an integer) and C<$str> is the name
string (which is the atom's name).  If there's no name for C<$cursor> then
C<$atom> is string "None" (or 0 if no C<$X-E<gt>{'do_interp'}>) and C<$str>
is empty "".

=item C<($x,$y, $width,$height, $xhot,$yhot, $serial, $pixels, $atom, $str) = $X-E<gt>XFixesGetCursorImageAndName ()>

Get the image and name of the current mouse pointer cursor.  The return is
per C<XFixesGetCursorImage()> plus C<XFixesGetCursorName()> described above.

=item C<$X-E<gt>XFixesChangeCursor ($src, $dst)>

Change the contents of cursor C<$dst> (an XID) to the contents of
cursor C<$src> (an XID).

=item C<$X-E<gt>XFixesChangeCursorByName ($src, $dst_str)>

Change the contents of any cursors with name C<$dst_str> (a string) to the
contents of cursor C<$src>.  If there's no cursors with name C<$dst_str>
then do nothing.

=back

=head2 XFIXES version 3.0

=over

=item C<$X-E<gt>XFixesExpandRegion ($src, $dst, $left,$right,$top,$bottom)>

Set region C<$dst> (an XID) to the rectangles of region C<$src>, with each
rectangle expanded by C<$left>, C<$right>, C<$top>, C<$bottom> many pixels
in those respective directions.

Notice it doesn't matter how C<$src> is expressed as rectangles, the effect
is as if each individual pixel in C<$src> was expanded and the union of the
result taken.

=back

=head2 XFIXES version 4.0

=over

=item C<$X-E<gt>XFixesHideCursor ($window)>

=item C<$X-E<gt>XFixesShowCursor ($window)>

Hide or show the mouse pointer cursor while it's in C<$window> (an XID) or
any subwindow of C<$window>.

This hiding for each window is a per-client setting.  If more than one
client requests hiding then the cursor remains hidden until all of them
"show" again.  If a client disconnects or is killed then its hides are
automatically undone.

=back

=head2 XFIXES version 5.0

=over

=item C<$X-E<gt>XFixesCreatePointerBarrier ($barrier, $drawable, $x1,$y1, $x2,$y2, $directions)>

=item C<$X-E<gt>XFixesCreatePointerBarrier ($barrier, $drawable, $x1,$y1, $x2,$y2, $directions, $deviceid...)>

Create C<$barrier> (a new XID) as a barrier object which prevents user mouse
pointer movement across a line between points C<$x1,$y1> and C<$x2,$y2>.
For example

    my $barrier = $X->new_rsrc;
    $X->XFixesCreatePointerBarrier ($barrier, $X->root,
                                    100,100, 100,500,
                                    0);

X,Y coordinates are screen coordinates on the screen of C<$drawable>.  The
line must be horizontal or vertical, so either C<$x1==$x2> or C<$y1==$y2>
(but not both).  A horizontal barrier is across the top edge of the line
pixels, a vertical barrier is along the left edge of the line pixels.

C<$directions> is an integer OR of the follow bits for which directions to
allow some movement across the line.  A value 0 means no movement across is
allowed.

    PositiveX    1
    PositiveY    2
    NegativeX    4
    NegativeY    8

For example on a horizontal line, value 8 would allow the pointer to move
through the line in the negative Y direction (up the screen), and movement
in the positive Y direction (down the screen) would still be forbidden.

C<$directions> can let the user move the mouse out of some sort of forbidden
region but not go back in.

Optional C<$deviceid> arguments are X Input Extension 2.0 devices the
barrier should apply to (see L<X11::Protocol::Ext::XInputExtension>).  With
no arguments the barrier is just for the core protocol mouse pointer.  Each
argument can be

    device ID                integer
    "AllDevices"             enum string, 0
    "AllMasterDevices"       enum string, 1

It's not necessary to C<$X-E<gt>init_extension('XInputExtension')> before
using this request.

The user can move the mouse pointer to go around a barrier line but by
putting lines together a region can be constructed keeping the pointer
inside or outside, or even making a maze to trick the user!

Touchscreen pad input is not affected by barriers, and
C<$X-E<gt>WarpPointer()> can still move the pointer anywhere.

One intended use is when a Xinerama screen (see
L<X11::Protocol::Ext::XINERAMA>) is made from monitors of different pixel
sizes so parts of the logical screen extent are off the edge of one of the
smaller monitors.  Barriers can prevent the user losing the mouse in one of
those dead regions.

For reference, some X.org server versions prior to some time around version
1.14 did not accept C<$deviceid> arguments in the request and gave a
C<Length> error on attempting to pass them.  Those servers might have given
an C<Implementation> error anyway (for barrier feature not yet implemented).

=item C<$X-E<gt>XFixesDestroyPointerBarrier ($barrier)>

Destroy the given barrier (an XID).

=back

=head1 EVENTS

The following events have the usual fields

    name             "XFixes..."
    synthetic        true if from a SendEvent
    code             integer opcode
    sequence_number  integer

=over

=item C<XFixesSelectionNotify>

This is sent to the client when selected by C<XFixesSelectSelectionInput>
above.  It reports changes to the selection.  The event-specific fields are

    subtype         enum string
    window          XID
    owner           XID of owner window, or "None"
    selection       atom integer
    time            integer, server timestamp
    selection_time  integer, server timestamp

C<subtype> is one of

    SetSelectionOwner
    SelectionWindowDestroy
    SelectionClientClose

C<time> is when the event was generated, C<selection_time> is when the
selection was owned.

=item C<XFixesCursorNotify>

This is sent to the client when selected by C<XFixesSelectCursorInput()>
above.  It reports when the currently displayed mouse pointer cursor has
changed.  It has the following event-specific fields,

    subtype         enum string, currently always "DisplayCursor"
    window          XID
    cursor_serial   integer
    time            integer, server timestamp
    cursor_name     atom or "None" (XFIXES 2.0 up)

C<subtype> is "DisplayCursor" when the displayed cursor has changed.  This
is the only subtype currently.

C<cursor_serial> is a serial number as per C<XFixesGetCursorImage()>.
A client can use this to notice when the displayed cursor is something it
has already fetched with C<XFixesGetCursorImage()>.

C<cursor_name> is the atom of the name given to the cursor by
C<XFixesSetCursorName>, or string "None" if no name.  This field is new in
XFIXES 2.0 and is present in the event unpack only if the server does XFIXES
2.0 or higher.  For C<$X-E<gt>pack_event()>, C<cursor_name> is optional and
the field is set if given.

=back

=head1 ERRORS

Error type "Region" is a bad C<$region> resource XID in a request (XFIXES
2.0 up).

=head1 SEE ALSO

L<X11::Protocol>,
L<X11::Protocol::Ext::SHAPE>,
L<X11::Protocol::Ext::RENDER>

F</usr/share/doc/x11proto-fixes-dev/fixesproto.txt.gz>

=head1 HOME PAGE

L<http://user42.tuxfamily.org/x11-protocol-other/index.html>

=head1 LICENSE

Copyright 2011, 2012, 2013, 2014 Kevin Ryde

X11-Protocol-Other is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3, or (at your option) any later
version.

X11-Protocol-Other is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
X11-Protocol-Other.  If not, see <http://www.gnu.org/licenses/>.

=cut
