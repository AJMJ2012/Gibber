version "4.0.0"

// Force an actor to gib via multi-hit like in Quake
// This however will override all base game gibbing logic
// The calculated gib health is Max(minGibHealth, baseGibHealth - baseHealth)

const debug = 0;

class Gibber_EventHandler : StaticEventHandler {
	override void WorldThingSpawned(WorldEvent e) {
		if (e.Thing.bSHOOTABLE) {
			e.Thing.GiveInventory("Gibber_DamageAccumulator", 1);
		}
	}
}

class Gibber_DamageAccumulator : Inventory {
	Name lastDamageType;
	Actor lastSource;
	Actor lastInflictor;

	int baseHealth;
	int gibHealth;
	int accumilatedDamage;

	Default { Inventory.MaxAmount 1; }

	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags) {
		if (passive) {
			// Convert damage into accumilated damage
			accumilatedDamage += damage;
			newdamage = 0;
			// Get the damage type, source and inflictor for the passive check
			self.lastDamageType = damageType;
			self.lastSource = source;
			self.lastInflictor = inflictor;

			// If there is enough damage to gib, then do it here. Allows overpenetration. Respects ExtremeDeath and NoExtremeDeath.
			bool isExtreme = accumilatedDamage >= owner.Health + self.gibHealth && !((source ? source.bNOEXTREMEDEATH : false) || (inflictor ? inflictor.bNOEXTREMEDEATH : false));
			bool forceExtreme = accumilatedDamage >= owner.Health && (source ? source.bEXTREMEDEATH : false) || (inflictor ? inflictor.bEXTREMEDEATH : false);
			if (isExtreme || forceExtreme) {
				ApplyDamage(accumilatedDamage, damageType, source, inflictor, true);
			}
		}
	}

	override void AttachToOwner(Actor other) {
		Super.AttachToOwner(other);
		let d = GetDefaultByType(other.GetClass());
		self.baseHealth = d.health;
	}

    override void DoEffect() {
		if (owner && owner.health > 0) {
			self.gibHealth = Max(CVar.GetCVar("sv_mingibhealth").GetInt(), CVar.GetCVar("sv_basegibhealth").GetInt() - self.baseHealth);
			int lastHealth = owner.Health;
			if (accumilatedDamage > 0) {
				// Deal Accumilated Damage. Does not handle gibbing. Forces no gibbing.
				ApplyDamage(accumilatedDamage, self.lastDamageType, self.lastSource, self.lastInflictor);
			}
			if (accumilatedDamage < lastHealth) {
				accumilatedDamage = 0;
			}
		}
	}

	void ApplyDamage(int damage, Name damageType, Actor source, Actor inflictor = null, bool extreme = false) {
		int damageFlags = DMSS_NOPROTECT|DMSS_NOFACTOR; // Don't want ModifyDamage to be called again
		if ((inflictor ? inflictor.bFOILINVUL : false) || (source ? source.bFOILINVUL : false)) {
			damageFlags |= DMSS_FOILINVUL;
		}
		if ((inflictor ? inflictor.bFOILBUDDHA : false) || (source ? source.bFOILBUDDHA : false)) {
			damageFlags |= DMSS_FOILBUDDHA;
		}
		int ptr = AAPTR_DEFAULT;
		Actor lastTracer = owner.Tracer;
		string type;

		if (damage >= owner.Health) {
			type = extreme ? "gibbed" : "killed";
			owner.Target = source; // Force set the target to whatever killed it
			ptr = AAPTR_TARGET;
		}
		else {
			type = "damaged";
			owner.Tracer = source; // Gotta use Tracer to not mess with vanilla target handling
			ptr = AAPTR_TRACER;
		}

		// Debug messages
		if (debug) {
			console.printf(owner.GetTag() .. " " .. type .. " by " .. (source != null ? source.GetTag() : (inflictor ? inflictor.GetTag() : "Unknown Causes")) .. " with damage " .. damage .. " of type " .. damageType .. " (BaseHealth: " .. self.baseHealth .. " | Health: " .. owner.Health .. " | HealthAfter: " .. (owner.Health - damage) .. " | GibHealth: -" .. self.gibHealth .. ")");
			if (type == "damaged" && extreme) 
				console.printf("Warning: Extreme variable was set but the damage wasn't lethal");
		}

		// Force either gibbing or not
		bool sourceBaseFlag;
		bool inflictorBaseFlag;
		if (extreme) {
			if (source) {
				sourceBaseFlag = source.bEXTREMEDEATH;
				source.bEXTREMEDEATH = true;
			}
			if (inflictor) {
				inflictorBaseFlag = inflictor.bEXTREMEDEATH;
				inflictor.bEXTREMEDEATH = true;
			}
		}
		else {
			if (source) {
				sourceBaseFlag = source.bNOEXTREMEDEATH;
				source.bNOEXTREMEDEATH = true;
			}
			if (inflictor) {
				inflictorBaseFlag = inflictor.bNOEXTREMEDEATH;
				inflictor.bNOEXTREMEDEATH = true;
			}
		}

		// Deal the damage
		owner.A_DamageSelf(damage, damageType, damageFlags, src: ptr, inflict: ptr);
		owner.Tracer = lastTracer; // Restore tracer if it's used by some other mod

		// Restore flags
		if (extreme) {
			if (source) {
				source.bEXTREMEDEATH = sourceBaseFlag;
			}
			if (inflictor) {
				inflictor.bEXTREMEDEATH = inflictorBaseFlag;
			}
		}
		else {
			if (source) {
				source.bNOEXTREMEDEATH = sourceBaseFlag;
			}
			if (inflictor) {
				inflictor.bNOEXTREMEDEATH = inflictorBaseFlag;
			}
		}
	}
}