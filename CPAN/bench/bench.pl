# Benchmark preamble.

sub need {
	my ($module, $version, @imports) = @_;
	if (!eval "require $module; 1") {
		die "E: $module needed.\n";
	}
	if ($version && !eval { $module->VERSION($version); 1 }) {
		die "E: $module$version needed (this is"
		. " only version @{[$module->VERSION]})\n";
	}
	warn "$module @{[$module->VERSION]} found.\n";
	$module->import(@imports) if @imports;
	return 1;
}

sub want {
	my ($module, $version, @imports) = @_;
	if (!eval "require $module; 1") {
		warn "$module not found?\n";
		return;
	}
	if ($version && !eval { $module->VERSION($version); 1 }) {
		warn "W: $module $version needed (this is"
		. " only version @{[$module->VERSION]})\n";
		return;
	}
	warn "$module @{[$module->VERSION]} found.\n";
	if (@imports) {
		eval { $module->import(@imports); 1 }
		or warn "W: $module import error: $@";
		return;
	}
	return 1;
}

sub have {
	my ($module, $version) = @_;
	my $filename = $module;
	$filename =~ s{::}{/}g;
	$filename .= '.pm';
	defined $INC{$filename} and !$version ||
	eval { $module->VERSION($version); 1 };
}

use Benchmark ();
return 1;
