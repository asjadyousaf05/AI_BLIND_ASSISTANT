package com.example.ai_blind_assistant

import org.junit.Assert.*
import org.junit.Test

class ReaderBargeInGateTest {
    @Test fun requiresStableMultiwordSpeechAndOneClaim() {
        val gate = ReaderBargeInGate()
        assertNull(gate.observe("stop reading", 100))
        assertNull(gate.observe("stop reading", 300))
        val candidate = gate.observe("stop reading", 360)!!
        assertEquals("stop reading", candidate.transcript)
        assertNull(gate.observe("stop reading", 600))
        assertEquals("stop reading", gate.consume(candidate.id, 610))
        assertNull(gate.consume(candidate.id, 620))
    }

    @Test fun changedPartialAndDecoderResetInvalidateOldProposal() {
        val gate = ReaderBargeInGate()
        gate.observe("read first line", 0)
        val first = gate.observe("read first line", 300)!!
        gate.observe("read last line", 310)
        assertNull(gate.consume(first.id, 320))
        val second = gate.observe("read last line", 600)!!
        gate.reset()
        assertNull(gate.consume(second.id, 610))
    }

    @Test fun rejectsExpiredWrongAndSingleWordCandidates() {
        val gate = ReaderBargeInGate()
        gate.observe("stop", 0)
        assertNull(gate.observe("stop", 1000))
        gate.observe("spell out", 1100)
        val candidate = gate.observe("spell out", 1400)!!
        assertNull(gate.consume("wrong", 1500))
        assertNull(gate.consume(candidate.id, 3000))
    }

    @Test fun unknownNoiseIsNotItselfACommand() {
        val gate = ReaderBargeInGate()
        gate.observe("[unk]", 0)
        assertNull(gate.observe("[unk]", 1000))
        gate.observe("[unk] pause reading [unk]", 1100)
        assertEquals("pause reading", gate.observe("[unk] pause reading [unk]", 1400)!!.transcript)
    }
}
