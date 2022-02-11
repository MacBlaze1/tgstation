/datum/component/forensics
	dupe_mode = COMPONENT_DUPE_UNIQUE
	can_transfer = TRUE
	var/list/fingerprints //assoc print = print
	var/list/hiddenprints //assoc ckey = realname/gloves/ckey
	var/list/blood_DNA //assoc dna = bloodtype
	var/list/fibers //assoc print = print
	var/list/cleaning //assoc source = number of cleanings
	var/times_cleaned = 0
	var/clean_constant = (1/4)
	var/clean_offset = 8
	var/minimum_max_char_clean = 3
	var/times_scanned = 0

/datum/component/forensics/InheritComponent(datum/component/forensics/F, original) //Use of | and |= being different here is INTENTIONAL.
	fingerprints = LAZY_LISTS_OR(fingerprints, F.fingerprints)
	hiddenprints = LAZY_LISTS_OR(hiddenprints, F.hiddenprints)
	blood_DNA = LAZY_LISTS_OR(blood_DNA, F.blood_DNA)
	fibers = LAZY_LISTS_OR(fibers, F.fibers)
	cleaning = LAZY_LISTS_OR(cleaning, F.cleaning)
	check_blood()
	return ..()

/datum/component/forensics/Initialize(new_fingerprints, new_hiddenprints, new_blood_DNA, new_fibers, new_cleaning)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	fingerprints = new_fingerprints
	hiddenprints = new_hiddenprints
	blood_DNA = new_blood_DNA
	fibers = new_fibers
	cleaning = new_cleaning
	check_blood()

/datum/component/forensics/RegisterWithParent()
	check_blood()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, .proc/clean_act)
	RegisterSignal(parent, COMSIG_CLOTHING_DETECTIVE_SCANNED, .proc/scanned)

/datum/component/forensics/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT))
	UnregisterSignal(parent, list(COMSIG_CLOTHING_DETECTIVE_SCANNED))

/datum/component/forensics/PostTransfer()
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/forensics/proc/handle_wipe(var/list/evidence_kind_list)
	for	(var/evidence in evidence_kind_list)
		var/num_char_wiped = rand(0,max(minimum_max_char_clean,round(-(NUM_E**(clean_constant*times_cleaned))+clean_offset,1)))
		for(var/i = 1 to num_char_wiped)
			var/insert_pos = rand(1,LAZYLEN(LAZYACCESS(evidence_kind_list,evidence))-1)
			LAZYSET(evidence_kind_list, evidence, splicetext(LAZYACCESS(evidence_kind_list,evidence),insert_pos,insert_pos+1,"-"))
	return evidence_kind_list

/datum/component/forensics/proc/wipe_fingerprints()
	handle_wipe(fingerprints)
	return TRUE

/datum/component/forensics/proc/wipe_hiddenprints()
	return //no.

/datum/component/forensics/proc/wipe_blood_DNA()
	return TRUE

/datum/component/forensics/proc/wipe_fibers()
	for(var/fiber in fibers)
		handle_wipe(LAZYACCESS(fibers,fiber))
	return TRUE

/datum/component/forensics/proc/scanned(datum/source)
	times_scanned +=1

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
	times_cleaned +=1

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

/datum/component/forensics/proc/add_fiber_list(list/_fiber_id) //list(text)
	if(!length(_fiber_id))
		return
	LAZYINITLIST(fibers)
	for(var/i in _fiber_id) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		fibers[i] = i
	return TRUE

/datum/component/forensics/proc/add_fibers(mob/living/carbon/human/M)
	var/item_multiplier = isitem(src)?1.2:1
	var/fiber_id
	var/fiber_text
	var/list/fiberid_fibertext
	LAZYINITLIST(fiberid_fibertext)
	if(M.wear_suit)
		fiber_text = "Material from \a [M.wear_suit]."
		fiber_id = md5(REF(M.wear_suit))
		if(prob(10*item_multiplier) && !LAZYACCESS(fibers, fiber_id))
			LAZYCLEARLIST(fiberid_fibertext)
			LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
			LAZYSET(fibers, fiber_id, fiberid_fibertext)
		if(!(M.wear_suit.body_parts_covered & CHEST))
			if(M.w_uniform)
				fiber_text = "Fibers from \a [M.w_uniform]."
				fiber_id = md5(REF(M.w_uniform))
				if(prob(12*item_multiplier) && !LAZYACCESS(fibers, fiber_id)) //Wearing a suit means less of the uniform exposed.
					LAZYCLEARLIST(fiberid_fibertext)
					LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
					LAZYSET(fibers, fiber_id, fiberid_fibertext)
		if(!(M.wear_suit.body_parts_covered & HANDS))
			if(M.gloves)
				fiber_text = "Material from a pair of [M.gloves.name]."
				fiber_id = md5(REF(M.gloves))
				if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fiber_id))
					LAZYCLEARLIST(fiberid_fibertext)
					LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
					LAZYSET(fibers, fiber_id, fiberid_fibertext)
	else if(M.w_uniform)
		fiber_text = "Fibers from \a [M.w_uniform]."
		fiber_id = md5(REF(M.w_uniform))
		if(prob(15*item_multiplier) && !LAZYACCESS(fibers, fiber_id))
			LAZYCLEARLIST(fiberid_fibertext)
			LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
			LAZYSET(fibers, fiber_id, fiberid_fibertext)
		if(M.gloves)
			fiber_text = "Material from a pair of [M.gloves.name]."
			fiber_id = md5(REF(M.gloves))
			if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fiber_id))
				LAZYCLEARLIST(fiberid_fibertext)
				LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
				LAZYSET(fibers, fiber_id,fiberid_fibertext)
	else if(M.gloves)
		fiber_text = "Material from a pair of [M.gloves.name]."
		fiber_id = md5(REF(M.gloves))
		if(prob(20*item_multiplier) && !LAZYACCESS(fibers, fiber_id))
			LAZYCLEARLIST(fiberid_fibertext)
			LAZYADDASSOC(fiberid_fibertext,fiber_text,fiber_id)
			LAZYSET(fibers, fiber_id,fiberid_fibertext)
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
	for(var/i in dna)
		blood_DNA[i] = dna[i]
	check_blood()
	return TRUE

/datum/component/forensics/proc/check_blood()
	if(!isitem(parent))
		return
	if(!length(blood_DNA))
		return
	parent.AddElement(/datum/element/decal/blood)
