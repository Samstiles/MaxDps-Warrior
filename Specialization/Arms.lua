local _, addonTable = ...;
--- @type MaxDps
if not MaxDps then
	return
end

local Warrior = addonTable.Warrior;
local MaxDps = MaxDps;
local UnitPower = UnitPower;
local PowerTypeRage = Enum.PowerType.Rage;

local Necrolord = Enum.CovenantType.Necrolord;
local Venthyr = Enum.CovenantType.Venthyr;
local NightFae = Enum.CovenantType.NightFae;
local Kyrian = Enum.CovenantType.Kyrian;
local debug = true

function debugPrint(message, data)
	if (debug) then
		if data ~= nil then
			print(message, data)
		else
			print(message)
		end
	end
end

local AR = {
	Charge            = 100,
	SweepingStrikes   = 260708,
	Bladestorm        = 227847,
	Ravager           = 152277,
	Massacre          = 281001,
	DeadlyCalm        = 262228,
	Rend              = 772,
	Skullsplitter     = 260643,
	Avatar            = 107574,
	ColossusSmash     = 167105,
	ColossusSmashAura = 208086,
	Cleave            = 845,
	DeepWoundsAura    = 262115,
	Warbreaker        = 262161,
	Condemn           = 330334,
	SuddenDeath       = 29725,
	SuddenDeathAura   = 52437,
	Overpower         = 7384,
	MortalStrike      = 12294,
	Dreadnaught       = 262150,
	Whirlwind         = 1680,
	FervorOfBattle    = 202316,
	Slam              = 1464,
	BloodFury         = 20572,
};

setmetatable(AR, Warrior.spellMeta);

function Warrior:SingleTarget()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local talents = fd.talents;
	local debuff = fd.debuff;
	local spellChosen = false
	local chosenSpell = nil
	local secondsRemainingOnDeepWoundsForRefreshPriority = 4
	local secondsRemainingOnRendForRefreshPriority = 4
	local colossusSmashReadyInTheNextEightSeconds = false
	local colossusSmashReadyNow = false
	local deepWoundsNeedsRefresh = false
	local rendNeedsRefresh = false

	if talents[AR.Warbreaker] then
		colossusSmashReadyNow = cooldown[AR.Warbreaker].remains == 0
		colossusSmashReadyInTheNextEightSeconds = cooldown[AR.Warbreaker].remains < 8
	else
		colossusSmashReadyNow = cooldown[AR.ColossusSmash].remains == 0
		colossusSmashReadyInTheNextEightSeconds = cooldown[AR.ColossusSmash].remains < 8
	end
	
	if debuff[AR.DeepWoundsAura].remains < secondsRemainingOnDeepWoundsForRefreshPriority then
		deepWoundsNeedsRefresh = true
	end

	if talents[AR.Rend] and debuff[AR.Rend].remains < secondsRemainingOnRendForRefreshPriority then
		rendNeedsRefresh = true
	end

	debugPrint(" ")
	debugPrint("--- Running single target arms rotation ---");

	-- Priority #0: Casting avatar (if talented) in conjunction with colossus smash debuff
	if talents[AR.Avatar] == 1 and
	   cooldown[AR.Avatar].ready and
	   colossusSmashReadyInTheNextEightSeconds then
		MaxDps:GlowCooldown(
			AR.Avatar,
			cooldown[AR.Avatar].ready and
			colossusSmashReadyInTheNextEightSeconds
		);

		-- debugPrint("Avatar talented?", talents[AR.Avatar] == 1)
		-- debugPrint("Avatar ready?", cooldown[AR.Avatar].ready)
		-- debugPrint("Colossus smash has <8 seconds left on its cooldown?", colossusSmashReadyInTheNextEightSeconds)
		debugPrint("* CHOOSING PRIORITY #0 (AVATAR)")
	else
		debugPrint("SKIPPING PRIORITY #0 (AVATAR)")
	end

	-- Priority #1: Casting colossus smash or warbreaker (if talented)
	if colossusSmashReadyNow then
		-- debugPrint("Colossus smash and/or warbreaker ready now?", colossusSmashReadyNow)
		debugPrint("* CHOOSING PRIORITY #1 (WARBREAKER/COLOSSUS SMASH)")
		spellChosen = true
		if talents[AR.Warbreaker] then
			chosenSpell = AR.Warbreaker
		else
			chosenSpell = AR.ColossusSmash
		end
	else
		debugPrint("SKIPPING PRIORITY #1 (WARBREAKER/COLOSSUS SMASH)")
	end

	-- Priority #1a (optional depends on if talented): Rend refresh
	if talents[AR.Rend] then
		if spellChosen == false and rendNeedsRefresh then
			-- debugPrint("talents[AR.Rend]", talents[AR.Rend])
			-- debugPrint("rendNeedsRefresh", rendNeedsRefresh)
			debugPrint("* CHOOSING PRIORITY #1a (REND REFRESH)")
			spellChosen = true
			chosenSpell = AR.Rend
		else
			debugPrint("SKIPPING PRIORITY #1a (REND REFRESH)")
		end
	end

	-- Priority #1b (optional depends on if talented): cast Skullsplitter when <60 rage, and bladestorm isn't gonna be used soon
	if talents[AR.Skullsplitter] then
		if spellChosen == false and cooldown[AR.Skullsplitter].ready and fd.rage < 60 and cooldown[AR.Bladestorm].ready == false then
			-- debugPrint("talents[AR.Warbreaker]", talents[AR.Warbreaker])
			-- debugPrint("cooldown[AR.Skullsplitter].ready", cooldown[AR.Skullsplitter].ready)
			-- debugPrint("rage < 60", fd.rage < 60)
			-- debugPrint("cooldown[AR.Bladestorm].ready == false", cooldown[AR.Bladestorm].ready == false)
			debugPrint("* CHOOSING PRIORITY #1b (skullsplitter if talented, and low rage and not using bladestorm soon)")
			spellChosen = true
			chosenSpell = AR.Skullsplitter
		else
			debugPrint("SKIPPING PRIORITY #1b (skullsplitter if talented, and low rage and not using bladestorm soon)")
		end
	end

	-- Priority #2: Mortal Strike for Deep Wounds Refresh
	if spellChosen == false and deepWoundsNeedsRefresh and cooldown[AR.MortalStrike].ready then
		-- debugPrint("Deep wounds needs refresh?", deepWoundsNeedsRefresh)
		-- debugPrint("Mortal strike ready?", cooldown[AR.MortalStrike].ready)
		debugPrint("* CHOOSING PRIORITY #2 (MORTAL STRIKE FOR DEEP WOUNDS REFRESH)")
		spellChosen = true
		chosenSpell = AR.MortalStrike
	else
		debugPrint("SKIPPING PRIORITY #2 (MORTAL STRIKE FOR DEEP WOUNDS REFRESH)")
	end

	-- Priority #3: Overpower
	if spellChosen == false and cooldown[AR.Overpower].ready then
		-- debugPrint("Overpower ready?", cooldown[AR.Overpower].ready)
		debugPrint("* CHOOSING PRIORITY #3 (OVERPOWER)")
		spellChosen = true
		chosenSpell = AR.Overpower
	else
		debugPrint("SKIPPING PRIORITY #3 (OVERPOWER)")
	end

	-- Priority #4: Execute/Condemn
	if spellChosen == false and fd.canExecute then
		-- debugPrint("Can execute/condemn?", fd.canExecute)
		-- debugPrint("Venthyr", Venthyr)
		-- debugPrint("covenentId", fd.covenantId)
		-- debugPrint("Is player venthyr?", fd.covenantId == Venthyr)
		debugPrint("* CHOOSING PRIORITY #4 (CONDEMN/EXECUTE)")
		spellChosen = true
		if fd.covenantId == Venthyr then
			chosenSpell = AR.Condemn
		else
			chosenSpell = AR.Execute
		end
	else
		debugPrint("SKIPPING PRIORITY #4 (CONDEMN/EXECUTE)")
	end

	-- Priority #5: Mortal Strike Generic
	if spellChosen == false and cooldown[AR.MortalStrike].ready and fd.rage > 30 then
		-- debugPrint("Mortal strike ready?", cooldown[AR.MortalStrike].ready)
		debugPrint("* CHOOSING PRIORITY #5 (MORTAL STRIKE GENERIC)")
		spellChosen = true
		chosenSpell = AR.MortalStrike
	else
		debugPrint("SKIPPING PRIORITY #5 (MORTAL STRIKE GENERIC)")
	end

	-- Priority #6: Bladestorm during colossus smash
	if spellChosen == false and debuff[AR.ColossusSmashAura].remains > 5 and cooldown[AR.Bladestorm].ready then
		-- debugPrint("debuff[AR.ColossusSmashAura].remains", debuff[AR.ColossusSmashAura].remains)
		-- debugPrint("cooldown[AR.Bladestorm].ready", cooldown[AR.Bladestorm].ready)
		debugPrint("* CHOOSING PRIORITY #6 (BLADESTORM DURING COLOSSUS SMASH)")
		spellChosen = true
		chosenSpell = AR.Bladestorm
	else
		debugPrint("SKIPPING PRIORITY #6 (BLADESTORM DURING COLOSSUS SMASH)")
	end


	-- Priority #7: Slam Or Whirlwind (depending on fervor talent)
	if spellChosen == false then
		if talents[AR.FervorOfBattle] then
			if fd.rage > 30 then
				debugPrint("* CHOOSING PRIORITY #7 (WHIRLWIND)")
				spellChosen = true
				chosenSpell = AR.Whirlwind
			else 
				debugPrint("SKIPPING PRIORITY #7 (WHIRLWIND)")
			end
		else
			if fd.rage > 20 then
				debugPrint("* CHOOSING PRIORITY #7 (SLAM)")
				spellChosen = true
				chosenSpell = AR.Slam
			else
				debugPrint("SKIPPING PRIORITY #7 (SLAM)")
			end
		end
	end

	if chosenSpell then
		return chosenSpell
	else
		debugPrint(" -- NO ACTIONS DETERMINED THIS FRAME -- LITERALLY STAND THERE AND AUTO ATTACK --")
	end
end

function Warrior:TwoOrThreeTargets()
end

function Warrior:FourOrMoreTargets()
end

function Warrior:Arms()
	local fd = MaxDps.FrameData;
	local talents = fd.talents;
	local targets = 1 --MaxDps:SmartAoe();
	local targetHp = MaxDps:TargetPercentHealth() * 100;
	local covenantId = fd.covenant.covenantId;
	local rage = UnitPower('player', PowerTypeRage);
	local canExecute = talents[AR.SuddenDeath] and fd.buff[AR.SuddenDeathAura].up --false
					   --rage > 20 and                                                  -- player has enough rage to execute, and any of the below conditions are met...
					   --(targetHp < 20 or                                              -- target is <20% hp
	                   --(talents[AR.Massacre] and targetHp < 35) or                    -- massacre is talented, and the target is <35% hp
		               --(targetHp > 80 and covenantId == Venthyr) or                   -- player is venthyr, and target is >80% hp
		               --(talents[AR.SuddenDeath] and fd.buff[AR.SuddenDeathAura].up));    -- sudden death is talented, and the sudden death aura is active on the player


	fd.rage = rage;
	fd.targetHp = targetHp;
	fd.targets = targets;
	fd.covenantId = covenantId;
	fd.canExecute = canExecute;

	if targets >= 4 then
		return Warrior:FourOrMoreTargets();
	end

	if (targets >= 2) then
		return Warrior:TwoOrThreeTargets();
	end

	return Warrior:SingleTarget();

	-- -- sweeping_strikes,if=spell_targets.whirlwind>1&(cooldown.bladestorm.remains>15|talent.ravager.enabled);
	-- if cooldown[AR.SweepingStrikes].ready and
	-- 	targets > 1 and
	-- 	(cooldown[AR.Bladestorm].remains > 15 or talents[AR.Ravager])
	-- then
	-- 	return AR.SweepingStrikes;
	-- end

	-- -- run_action_list,name=hac,if=raid_event.adds.exists;
	-- if targets > 1 then
	-- 	return Warrior:ArmsHac();
	-- end

	-- -- run_action_list,name=execute,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20|(target.health.pct>80&covenant.venthyr);
	-- if canExecute then
	-- 	return Warrior:ArmsExecute();
	-- end

	-- -- run_action_list,name=single_target;
	-- return Warrior:ArmsSingleTarget();
end

function Warrior:ArmsExecute()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local talents = fd.talents;
	local targets = fd.targets;
	local canExecute = fd.canExecute;
	local rage = fd.rage;
	local covenantId = fd.covenant.covenantId;

	-- deadly_calm;
	if talents[AR.DeadlyCalm] and cooldown[AR.DeadlyCalm].ready then
		return AR.DeadlyCalm;
	end

	-- rend,if=remains<=duration*0.3;
	if talents[AR.Rend] and rage >= 30 and debuff[AR.Rend].refreshable then
		return AR.Rend;
	end

	-- skullsplitter,if=rage<60&(!talent.deadly_calm.enabled|buff.deadly_calm.down);
	if talents[AR.Skullsplitter] and
		cooldown[AR.Skullsplitter].ready and
		rage < 60 and
		(not talents[AR.DeadlyCalm] or not buff[AR.DeadlyCalm].up)
	then
		return AR.Skullsplitter;
	end

	-- avatar,if=cooldown.colossus_smash.remains<8&gcd.remains=0;
	--if talents[AR.Avatar] and cooldown[AR.Avatar].ready and cooldown[AR.ColossusSmash].remains < 8 then
	--	return AR.Avatar;
	--end

	-- ravager,if=buff.avatar.remains<18&!dot.ravager.remains;
	if talents[AR.Ravager] and
		cooldown[AR.Ravager].ready and
		buff[AR.Avatar].remains < 18
		--and
		--not debuff[AR.Ravager].up
	then
		return AR.Ravager;
	end

	-- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd;
	if talents[AR.Cleave] and
		cooldown[AR.Cleave].ready and
		rage >= 20 and
		targets > 1 and
		debuff[AR.DeepWoundsAura].remains < 2
	then
		return AR.Cleave;
	end

	-- warbreaker;
	if talents[AR.Warbreaker] then
		if cooldown[AR.Warbreaker].ready then
			return AR.Warbreaker;
		end
	else
		-- colossus_smash;
		if cooldown[AR.ColossusSmash].ready then
			return AR.ColossusSmash;
		end
	end

	-- condemn,if=debuff.colossus_smash.up|buff.sudden_death.react|rage>65;
	if covenantId == Venthyr and
		rage >= 20 and
		canExecute and
		cooldown[AR.Condemn].ready
	then
		return AR.Condemn;
	end

	-- overpower,if=charges=2;
	if cooldown[AR.Overpower].ready and cooldown[AR.Overpower].charges >= 2 then
		return AR.Overpower;
	end

	-- bladestorm,if=buff.deadly_calm.down&rage<50;
	if not talents[AR.Ravager] and cooldown[AR.Bladestorm].ready and not buff[AR.DeadlyCalm].up and rage < 50 then
		return AR.Bladestorm;
	end

	-- mortal_strike,if=dot.deep_wounds.remains<=gcd;
	if cooldown[AR.MortalStrike].ready and
		rage >= 30 and
		debuff[AR.DeepWoundsAura].remains <= 2
	then
		return AR.MortalStrike;
	end

	-- skullsplitter,if=rage<40;
	if talents[AR.Skullsplitter] and cooldown[AR.Skullsplitter].ready and rage < 40 then
		return AR.Skullsplitter;
	end

	-- overpower;
	if cooldown[AR.Overpower].ready then
		return AR.Overpower;
	end

	-- condemn;
	if covenantId == Venthyr then
		if cooldown[AR.Condemn].ready and canExecute then
			return AR.Condemn;
		end
	else
		-- execute;
		if cooldown[AR.Execute].ready and canExecute then
			return AR.Execute;
		end
	end
end

function Warrior:ArmsHac()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local talents = fd.talents;
	local rage = fd.rage;
	local covenantId = fd.covenant.covenantId;
	local canExecute = fd.canExecute;

	-- skullsplitter,if=rage<60&buff.deadly_calm.down;
	if talents[AR.Skullsplitter] and
		cooldown[AR.Skullsplitter].ready and
		rage < 60 and
		not buff[AR.DeadlyCalm].up
	then
		return AR.Skullsplitter;
	end

	-- avatar,if=cooldown.colossus_smash.remains<1;
	--if talents[AR.Avatar] and cooldown[AR.Avatar].ready and (cooldown[AR.ColossusSmash].remains < 1) then
	--	return AR.Avatar;
	--end

	-- cleave,if=dot.deep_wounds.remains<=gcd;
	if talents[AR.Cleave] and
		cooldown[AR.Cleave].ready and
		rage >= 20 and
		debuff[AR.DeepWoundsAura].remains <= 2
	then
		return AR.Cleave;
	end

	-- warbreaker;
	if talents[AR.Warbreaker] and cooldown[AR.Warbreaker].ready then
		return AR.Warbreaker;
	end

	if talents[AR.Ravager] then
		-- ravager;
		if cooldown[AR.Ravager].ready then
			return AR.Ravager;
		end
	else
		-- bladestorm;
		if cooldown[AR.Bladestorm].ready then
			return AR.Bladestorm;
		end
	end

	-- colossus_smash;
	if not talents[AR.Warbreaker] and cooldown[AR.ColossusSmash].ready then
		return AR.ColossusSmash;
	end

	-- rend,if=remains<=duration*0.3&buff.sweeping_strikes.up;
	if talents[AR.Rend] and
		rage >= 30 and
		debuff[AR.Rend].refreshable and
		buff[AR.SweepingStrikes].up
	then
		return AR.Rend;
	end

	-- cleave;
	if talents[AR.Cleave] and cooldown[AR.Cleave].ready and rage >= 20 then
		return AR.Cleave;
	end

	-- mortal_strike,if=buff.sweeping_strikes.up|dot.deep_wounds.remains<gcd&!talent.cleave.enabled;
	if cooldown[AR.MortalStrike].ready and
		rage >= 30 and
		(
			buff[AR.SweepingStrikes].up or
			debuff[AR.DeepWoundsAura].remains < 2 and not talents[AR.Cleave]
		)
	then
		return AR.MortalStrike;
	end

	-- overpower,if=talent.dreadnaught.enabled;
	if cooldown[AR.Overpower].ready and talents[AR.Dreadnaught] then
		return AR.Overpower;
	end

	if covenantId == Venthyr then
		-- condemn;
		if rage >= 20 and canExecute then
			return AR.Condemn;
		end
	else
		-- execute,if=buff.sweeping_strikes.up;
		if rage >= 20 and buff[AR.SweepingStrikes].up and cooldown[AR.Execute].ready then
			return AR.Execute;
		end
	end

	-- overpower;
	if cooldown[AR.Overpower].ready then
		return AR.Overpower;
	end

	-- whirlwind;
	if rage >= 30 then
		return AR.Whirlwind;
	end
end

function Warrior:ArmsSingleTarget()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local talents = fd.talents;
	local targets = fd.targets;
	local gcd = fd.gcd;
	local canExecute = fd.canExecute;
	local covenantId = fd.covenant.covenantId;
	local rage = fd.rage;

	-- avatar,if=cooldown.colossus_smash.remains<8&gcd.remains=0;
	--if talents[AR.Avatar] and cooldown[AR.Avatar].ready and (cooldown[AR.ColossusSmash].remains < 8 and gcdRemains == 0) then
	--	return AR.Avatar;
	--end

	-- rend,if=remains<=duration*0.3;
	if talents[AR.Rend] and
		rage >= 30 and
		debuff[AR.Rend].refreshable
	then
		return AR.Rend;
	end

	-- cleave,if=spell_targets.whirlwind>1&dot.deep_wounds.remains<gcd;
	if talents[AR.Cleave] and
		cooldown[AR.Cleave].ready and
		rage >= 20 and
		targets > 1 and
		debuff[AR.DeepWoundsAura].remains < 2
	then
		return AR.Cleave;
	end

	-- warbreaker;
	if talents[AR.Warbreaker] then
		if cooldown[AR.Warbreaker].ready then
			return AR.Warbreaker;
		end
	else
		-- colossus_smash;
		if cooldown[AR.ColossusSmash].ready then
			return AR.ColossusSmash;
		end
	end

	-- ravager,if=buff.avatar.remains<18&!dot.ravager.remains;
	if talents[AR.Ravager] and cooldown[AR.Ravager].ready and buff[AR.Avatar].remains < 18 then
		return AR.Ravager;
	end

	-- overpower,if=charges=2;
	if cooldown[AR.Overpower].charges >= 2 then
		return AR.Overpower;
	end

	-- bladestorm,if=buff.deadly_calm.down&(debuff.colossus_smash.up&rage<30|rage<70);
	if not talents[AR.Ravager] and
		cooldown[AR.Bladestorm].ready and
		not buff[AR.DeadlyCalm].up and
		(debuff[AR.ColossusSmashAura].up and rage < 30 or rage < 70)
	then
		return AR.Bladestorm;
	end

	-- mortal_strike,if=buff.overpower.stack>=2&buff.deadly_calm.down|(dot.deep_wounds.remains<=gcd&cooldown.colossus_smash.remains>gcd);
	if cooldown[AR.MortalStrike].ready and
		rage >= 30 and
		(
			buff[AR.Overpower].count >= 2 and not buff[AR.DeadlyCalm].up or
			(debuff[AR.DeepWoundsAura].remains <= 2 and cooldown[AR.ColossusSmash].remains > gcd)
		)
	then
		return AR.MortalStrike;
	end

	-- deadly_calm;
	if talents[AR.DeadlyCalm] and cooldown[AR.DeadlyCalm].ready then
		return AR.DeadlyCalm;
	end

	-- skullsplitter,if=rage<60&buff.deadly_calm.down;
	if talents[AR.Skullsplitter] and
		cooldown[AR.Skullsplitter].ready and
		rage < 60 and
		not buff[AR.DeadlyCalm].up
	then
		return AR.Skullsplitter;
	end

	-- overpower;
	if cooldown[AR.Overpower].ready then
		return AR.Overpower;
	end


	if rage >= 20 and buff[AR.SuddenDeath].up and canExecute then
		if covenantId == Venthyr then
			-- condemn,if=buff.sudden_death.react;
			return AR.Condemn;
		else
			-- execute,if=buff.sudden_death.react;
			return AR.Execute;
		end
	end

	-- mortal_strike;
	if cooldown[AR.MortalStrike].ready and rage >= 30 then
		return AR.MortalStrike;
	end

	-- whirlwind,if=talent.fervor_of_battle.enabled&rage>60;
	if rage >= 30 and talents[AR.FervorOfBattle] and rage > 60 then
		return AR.Whirlwind;
	end

	-- slam;
	if rage >= 20 then
		return AR.Slam;
	end
end