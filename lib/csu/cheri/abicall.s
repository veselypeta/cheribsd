.macro abicall dest
	# This can be removed once nothing is assuming it can jr $ra to return
	dla	$ra, 0f
	cgetpcc	$c12
	csetoffset	$c12, $c12, \dest
	cjalr	$c17, $c12
	nop			# Branch-delay slot
0:
.endm
