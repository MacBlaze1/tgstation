/datum/component/forensics
	dupe_mode = COMPONENT_DUPE_UNIQUE
	can_transfer = TRUE
	var/list/fingerprints //assoc print = print
	var/list/hiddenprints //assoc ckey = realname/gloves/ckey
	var/list/blood_DNA //assoc dna = bloodtype
	var/list/fibers //assoc print = print
	var/list/cleaning //assoc source = number of cleanings
	var/list/origin_changed_DNA // assoc original dna = obfuscated DNA
	var/clean_constant = (1/4)
	var/clean_offset = 8
	var/minimum_max_char_clean = 3

/datum/component/forensics/InheritComponent(datum/component/forensics/F, original) //Use of | and |= being different here is INTENTIONAL.
	fingerprints = LAZY_LISTS_OR(fingerprints, F.fingerprints)
	hiddenprints = LAZY_LISTS_OR(hiddenprints, F.hiddenprints)
	blood_DNA = LAZY_LISTS_OR(blood_DNA, F.blood_DNA)
	origin_changed_DNA = LAZY_LISTS_OR(origin_changed_DNA,F.origin_changed_DNA)
	fibers = LAZY_LISTS_OR(fibers, F.fibers)
	cleaning = LAZY_LISTS_OR(cleaning, F.cleaning)
	check_blood()
	return ..()

/datum/component/forensics/Initialize(new_fingerprints, new_hiddenprints, new_blood_DNA, new_origin_changed_DNA, new_fibers, new_cleaning)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	fingerprints = new_fingerprints
	hiddenprints = new_hiddenprints
	blood_DNA = new_blood_DNA
	origin_changed_DNA = new_origin_changed_DNA
	fibers = new_fibers
	cleaning = new_cleaning
	check_blood()

/datum/component/forensics/RegisterWithParent()
	check_blood()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, .proc/clean_act)

/datum/component/forensics/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT))

/datum/component/forensics/PostTransfer()
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/forensics/proc/handle_wipe(var/list/evidence_kind_list)
	var/num_char_wiped = 0
	var/insert_pos = 0
	var/total_clean = 0
	for (var/agent in cleaning)
		total_clean += LAZYACCESS(cleaning,agent)
	for	(var/evidence in evidence_kind_list)
		num_char_wiped = rand(0,max(minimum_max_char_clean,round(-(NUM_E**(clean_constant*total_clean))+clean_offset,1)))
		insert_pos = rand(1,length(evidence)-num_char_wiped)
		var/text
		for	(var/i in 1 to num_char_wiped)
			text += "X"
		LAZYSET(evidence_kind_list, evidence, splicetext(LAZYACCESS(evidence_kind_list,evidence),insert_pos,insert_pos+num_char_wiped,text))
	return evidence_kind_list

/datum/component/forensics/proc/wipe_fingerprints()
	handle_wipe(fingerprints)
	return TRUE

/datum/component/forensics/proc/wipe_hiddenprints()
	return //no.

/datum/component/forensics/proc/wipe_blood_DNA()
	handle_wipe(origin_changed_DNA)
	return TRUE

/datum/component/forensics/proc/wipe_fibers()
	handle_wipe(fibers)
	return TRUE

/datum/component/forensics/proc/clean_act(datum/source, clean_types, agent)
	SIGNAL_HANDLER

	. = NONE
	if(clean_types & CLEAN_TYPE_FINGERPRINTS)
		wipe_fingerprints()
		. = COMPONENT_CLEANED
	if(clean_types & CLEAN_TYPE_BLOOD)
		wipe_blood_DNA()
		. = COMPONENT_CLEANED
	if(clean_types & CLEAN_TYPE_FIBERS)
		wipe_fibers()
		. = COMPONENT_CLEANED
	if(!LAZYACCESS(cleaning,agent))
		LAZYSET(cleaning,agent,1)
	else
		LAZYSET(cleaning,agent,LAZYACCESS(cleaning,agent)+1)

/datum/component/forensics/proc/add_fingerprint_list(list/_fingerprints) //list(text)
	if(!length(_fingerprints))
		return
	LAZYINITLIST(fingerprints)
	for(var/i in _fingerprints) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		fingerprints[i] = i
	return TRUE

/datum/component/forensics/proc/add_fingerprint(mob/living/M, ignoregloves = FALSE)
	if(!isliving(M))
		if(!iscameramob(M))
			return
		if(isaicamera(M))
			var/mob/camera/ai_eye/ai_camera = M
			if(!ai_camera.ai)
				return
			M = ai_camera.ai
	add_hiddenprint(M)
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		add_fibers(H)
		if(H.gloves) //Check if the gloves (if any) hide fingerprints
			var/obj/item/clothing/gloves/G = H.gloves
			if(G.transfer_prints)
				ignoregloves = TRUE
			if(!ignoregloves)
				H.gloves.add_fingerprint(H, TRUE) //ignoregloves = 1 to avoid infinite loop.
				return
		var/full_print = md5(H.dna.unique_identity)
		if(!LAZYACCESS(fingerprints,full_print))
			LAZYSET(fingerprints, full_print, full_print)
	return TRUE

/datum/component/forensics/proc/add_fiber_list(list/_full_fiber) //list(text)
	if(!length(_full_fiber))
		return
	LAZYINITLIST(fibers)
	for(var/i in _full_fiber) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		fibers[i] = i
	return TRUE

/datum/component/forensics/proc/add_fibers(mob/living/carbon/human/M)
	var/item_multiplier = isitem(src)?1.2:1
	var/full_fiber
	if(M.wear_suit)
		full_fiber = md5(REF(M.wear_suit))
		if(prob(10*item_multiplier) && !LAZYACCESS(fibers, full_fiber))
			LAZYSET(fibers, full_fiber, full_fiber)
		if(!(M.wear_suit.body_parts_covered & CHEST))
			if(M.w_uniform)
				full_fiber = md5(REF(M.w_uniform))
				if(prob(12*item_multiplier) && !LAZYACCESS(fibers, full_fiber)) //Wearing a suit means less of the uniform exposed.
					LAZYSET(fibers, full_fiber, full_fiber)
		if(!(M.wear_suit.body_parts_covered & HANDS))
			if(M.gloves)
				full_fiber = md5(REF(M.gloves))
				if(prob(20*item_multiplier) && !LAZYACCESS(fibers, full_fiber))
					LAZYSET(fibers, full_fiber, full_fiber)
	else if(M.w_uniform)
		full_fiber = md5(REF(M.w_uniform))
		if(prob(15*item_multiplier) && !LAZYACCESS(fibers, full_fiber))
			// "Added full_fiber: [full_fiber]"
			LAZYSET(fibers, full_fiber, full_fiber)
		if(M.gloves)
			full_fiber = md5(REF(M.gloves))
			if(prob(20*item_multiplier) && !LAZYACCESS(fibers, full_fiber))
				LAZYSET(fibers, full_fiber, full_fiber)
	else if(M.gloves)
		full_fiber = md5(REF(M.gloves))
		if(prob(20*item_multiplier) && !LAZYACCESS(fibers, full_fiber))
			LAZYSET(fibers, full_fiber, full_fiber)
	return TRUE

/datum/component/forensics/proc/add_hiddenprint_list(list/_hiddenprints) //list(ckey = text)
	if(!length(_hiddenprints))
		return
	LAZYINITLIST(hiddenprints)
	for(var/i in _hiddenprints) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		hiddenprints[i] = _hiddenprints[i]
	return TRUE

/datum/component/forensics/proc/add_hiddenprint(mob/M)
	if(!isliving(M))
		if(!iscameramob(M))
			return
		if(isaicamera(M))
			var/mob/camera/ai_eye/ai_camera = M
			if(!ai_camera.ai)
				return
			M = ai_camera.ai
	if(!M.key)
		return
	var/hasgloves = ""
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.gloves)
			hasgloves = "(gloves)"
	var/current_time = time_stamp()
	if(!LAZYACCESS(hiddenprints, M.key))
		LAZYSET(hiddenprints, M.key, "First: \[[current_time]\] \"[M.real_name]\"[hasgloves]. Ckey: [M.ckey]")
	else
		var/laststamppos = findtext(LAZYACCESS(hiddenprints, M.key), "\nLast: ")
		if(laststamppos)
			LAZYSET(hiddenprints, M.key, copytext(hiddenprints[M.key], 1, laststamppos))
		hiddenprints[M.key] += "\nLast: \[[current_time]\] \"[M.real_name]\"[hasgloves]. Ckey: [M.ckey]" //made sure to be existing by if(!LAZYACCESS);else
	var/atom/A = parent
	A.fingerprintslast = M.ckey
	return TRUE

/datum/component/forensics/proc/add_blood_DNA(list/dna) //list(dna_enzymes = type)
	if(!length(dna))
		return
	LAZYINITLIST(blood_DNA)
	LAZYINITLIST(origin_changed_DNA)
	for(var/i in dna)
		blood_DNA[i] = dna[i]
		LAZYADDASSOC(origin_changed_DNA,dna,dna)
	check_blood()
	return TRUE

/datum/component/forensics/proc/check_blood()
	if(!isitem(parent))
		return
	if(!length(blood_DNA))
		return
	parent.AddElement(/datum/element/decal/blood)
