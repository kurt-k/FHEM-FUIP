package FUIP::View::Batteries;

use strict;
use warnings;

use lib::FUIP::View;
use parent -norequire, 'FUIP::View';
use lib::FUIP::Model;
	
	
sub getDependencies($$) {
	return ['js/fuip_5_resize.js','js/fuip_batteries.js'];
};
	

sub _getDevices($$){
	my ($name,$deviceFilter) = @_;
	my %devices;
	my @readings = qw(battery batteryLevel batVoltage batteryPercent);
	push(@readings,"Activity") if($deviceFilter eq "all");
	for my $reading (@readings) {
		for my $dev (@{FUIP::Model::getDevicesForReading($name,$reading)}) {
			$devices{$dev}{$reading} = 1;
		};	
	};
	# only devices with battery, but we want the Activity reading nevertheless, if it exists
	my $fields = ["alias","battery"];
	if($deviceFilter ne "all") {
		push(@$fields,"Activity");
	};	
	for my $dev (keys(%devices)) {
		my $device = FUIP::Model::getDevice($name,$dev,$fields);
		if(exists($device->{Readings}{Activity})) {
			$devices{$dev}{Activity} = 1;
		};
		if($device->{Attributes}{alias}) {
			$devices{$dev}{alias} = $device->{Attributes}{alias};
		};
		$devices{$dev}{battery} = $device->{Readings}{battery} if $devices{$dev}{battery};
		# own key
		$devices{$dev}{key} = $dev;
	};
	# we need a sorted array as a result
	# sort by alias (if exists), otherwise by key (NAME)
	# sort case-insensitive
	my @result = 
		sort {
			my $a_key = exists($a->{alias}) ? $a->{alias} : $a->{key};
			my $b_key = exists($b->{alias}) ? $b->{alias} : $b->{key};
			return CORE::fc($a_key) cmp CORE::fc($b_key); } values %devices;
	return \@result;
};	
	
	
sub _getHtmlName($) {
	my ($device) = @_;
	return '<div
		style="text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" 
		class="fuip-color fuip-devname">'
			.($device->{alias} ? $device->{alias} :$device->{key})
		.'</div>';
};


sub _getReadingType($$) {
# determine type of reading:
#	text:	ok/low etc.
#	percentage: percentage (without the % sign)
#	voltage:	voltage, without the V sign
	my ($device,$reading) = @_;
	return "percentage" if($reading eq "batteryPercent");
	return "voltage" if($reading =~ m/^(batteryLevel|batVoltage)$/);
	# now only "battery" is left, which usually is like ok/low etc., but can be percentage as well
	my $value = $device->{$reading};
	return "percentage" if($value =~ m/^\s*\d*\s*$/);	# i.e. (blanks,) digits (, blanks)
	return "text";
};


sub _getHtmlBatterySymbol($) {
	my ($device) = @_;
	my $reading;
	for my $r (qw(batteryLevel batVoltage batteryPercent battery)) {
		next unless exists($device->{$r});
		$reading = $r; 
		last;
	};	
	return "" unless $reading;	
	my $readingType = _getReadingType($device,$reading);
	my $result = '<div style="margin-top:-26px;margin-bottom:-30px;margin-right:-10px;margin-left:-10px;" 
					data-type="symbol" 
					data-device="'.$device->{key}.'" 
					data-get="'.$reading.'"'."\n";
	if($readingType eq "text") {
		$result .= 'data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_75 fa-rotate-90"]\''."\n";
	}else{
		$result .= 'data-icons=\'["oa-measure_battery_0 fa-rotate-90","oa-measure_battery_25 fa-rotate-90","oa-measure_battery_50 fa-rotate-90","oa-measure_battery_75 fa-rotate-90","oa-measure_battery_100 fa-rotate-90"]\''."\n";
	};
	if($readingType eq "percentage") {
		$result .= 'data-states=\'["0","10","35","60","90"]\''."\n";
	}elsif($readingType eq "text") {
		$result .= 'data-states=\'["((?!ok).)*","ok"]\''."\n";
	}else{
		$result .= 'data-states=\'["0","2.1","2.4","2.7","3.0"]\''."\n";
	};
	if($readingType eq "text") {
		$result .= 'data-colors=\'["red","green"]\'>'."\n";
	}else{
		$result .= 'data-colors=\'["red","yellow","green","green","green"]\'>'."\n";
	};
	$result .= '</div>';
	return $result;
};


sub _getHtmlBatteryLevel($) {
	my ($device) = @_;
	my $result = "";
	for my $reading (qw(batteryLevel batteryPercent battery batVoltage)) {
		next unless exists $device->{$reading};
		my $readingType = _getReadingType($device,$reading);
		next if $readingType eq "text";  # we do not want to see texts, just numbers here
		$result .= '<div data-type="label" 
						data-device="'.$device->{key}.'" 
						data-get="'.$reading.'" 
						data-unit="'.($readingType eq "percentage" ? '%' : 'V').'"
						class="fuip-color"></div>'."\n";	
		last;  # especially for those with userReadings				
	};
	return $result;
};	


sub _getHtmlActivity($) {
	my ($device) = @_;
	return "" unless exists($device->{Activity});
	return '<div data-type="label" 
				data-device="'.$device->{key}.'" 
				data-get="Activity" 
				data-colors=\'["red","green","yellow"]\' 
				data-limits=\'["dead","alive","unknown"]\'>
			</div>'."\n";
};


sub getHTML($){
	my ($self) = @_;
	my $result = '<div  data-fuip-type="fuip-batteries" style="overflow:auto;width:100%;height:100%;">
				<table style="border-spacing:0px;"><tr><td style="padding:0;">';
	my $devices = _getDevices($self->{fuip}{NAME},$self->{deviceFilter});				
	my $numDevs = @$devices;				
	my $count = 0;
	use integer;
	# avoid division by zero error
	$self->{columns} = 2 unless $self->{columns};
	my $perCol = $numDevs / $self->{columns} + ($numDevs % $self->{columns} ? 1 : 0);
	my $colWidth = 100 / ($self->{columns} + 1);
	$result .= '<table style="border-spacing:0px;">';
	for my $device (@$devices) {
		if($count == $perCol) {
			$result .= '</table></td><td style="padding:0;"><div style="width:25px;"></div></td><td style="padding:0;"><table style="table-layout:fixed;border-spacing:0px;">';
			$count = 0;
		}  
		$count++;
		$result.= '<tr>
					<td>'._getHtmlName($device).'</td>
					<td><div style="width:42px;">'._getHtmlBatterySymbol($device).'</div></td>
					<td><div style="width:30px">'._getHtmlBatteryLevel($device).'</div></td>
					<td style="padding-left:5px"><div style="width:54px">'._getHtmlActivity($device).'</div></td>
				</tr>';  
	}
	$result .= '</table>'; 
	$result .= '</td></tr></table></div>';
	return $result;	
};

	
sub dimensions($;$$){
	my ($self,$width,$height) = @_;
	if($self->{sizing} eq "resizable") {
		$self->{width} = $width if $width;
		$self->{height} = $height if $height;
	};
	
	# do we have to determine the size?
	# even if sizing is "auto", we at least determine an initial size
	# either resizable and no size yet
	# or fixed
	if(not $self->{height} or $self->{sizing} eq "fixed") {
		my $devices = _getDevices($self->{fuip}{NAME},$self->{deviceFilter});
		use integer;
		my $numDevs = @$devices;
		$self->{height} = 19 * ($numDevs / 2 + $numDevs % 2) + 8;
	};	
	if(not $self->{width} or $self->{sizing} eq "fixed") {
			$self->{width} = 650;
	};	
	return ("auto","auto") if($self->{sizing} eq "auto");
	return ($self->{width},$self->{height});
};		
	
	
sub reconstruct($$$) {
	my ($class,$conf,$fuip) = @_;
	my $self = FUIP::View::reconstruct($class,$conf,$fuip);
	# downward compatibility: automatically convert width to resizable
	return $self unless defined($self->{width});
	return $self unless $self->{width} =~ m/^(fixed|auto)$/;
	$self->{sizing} = $self->{width};
	delete $self->{width};
	if(defined($self->{defaulted}{width})) {
		$self->{defaulted}{sizing} = $self->{defaulted}{width};
		delete $self->{defaulted}{width};
	};	
	return $self;
};
	
	
sub getStructure($) {
	# class method
	# returns general structure of the view without instance values
	my ($class) = @_;
	return [
		{ id => "class", type => "class", value => $class },
		{ id => "title", type => "text", default => { type => "const", value => "Batteries"} },
		{ id => "deviceFilter", type => "text", options => [ "all", "battery"], 
			default => { type => "const", value => "all" } }, 
		{ id => "width", type => "dimension" },
		{ id => "height", type => "dimension" },
		{ id => "sizing", type => "sizing", options => [ "fixed", "auto", "resizable" ],
			default => { type => "const", value => "auto" } },
		{ id => "columns", type => "text", options => [1,2,3,4], 
			default => { type => "const", value => 2 } }
		];
};


# register me as selectable
$FUIP::View::selectableViews{"FUIP::View::Batteries"}{title} = "Batteries"; 
	
1;	