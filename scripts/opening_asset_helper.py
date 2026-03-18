#!/usr/bin/env python3

import argparse
import base64
import json
import math
import struct
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

import ndspy.color
import ndspy.lz10
import ndspy.narc
import ndspy.soundArchive
import ndspy.soundBank
import ndspy.soundSequence
import ndspy.texture
from nitrogfx.ncgr import NCGR, flip_tile
from nitrogfx.ncer import NCER
from nitrogfx.nclr import NCLR
import nitrogfx.nanr as nitro_nanr
from nitrogfx.nscr import NSCR
from PIL import Image, ImageChops


def patch_nitrogfx_nanr() -> None:
    def fixed_frame2_unpack(data: bytes):
        frame = nitro_nanr.Frame2()
        frame.index, _, frame.px, frame.py = struct.unpack("<HHHH", data[0:8])
        frame.duration = 0
        return frame

    nitro_nanr.Frame2.unpack = staticmethod(fixed_frame2_unpack)


patch_nitrogfx_nanr()
NANR = nitro_nanr.NANR
ndspy.color.prepareLUTs()
try:
    PIL_NEAREST = Image.Resampling.NEAREST
except AttributeError:
    PIL_NEAREST = Image.NEAREST


IMA_STEP_TABLE = [
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37,
    41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173,
    190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658,
    724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
    7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500,
    20350, 22385, 24623, 27086, 29794, 32767,
]

IMA_INDEX_TABLE = [
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8,
]

DEFAULT_OUTPUT_SAMPLE_RATE = 32728
TICKS_PER_QUARTER_NOTE = 48.0
ARM7_CLOCK = 33513982.0 / 2.0
SEQUENCE_TIMER_SECONDS = (64.0 * 2728.0) / 33513982.0
SEQUENCE_TICK_THRESHOLD = 240
SOUND_SINE_LUT = [
    0, 6, 12, 19, 25, 31, 37, 43, 49, 54, 60, 65, 71, 76, 81, 85, 90, 94,
    98, 102, 106, 109, 112, 115, 117, 120, 122, 123, 125, 126, 126, 127, 127,
]
ADSR_THRESHOLD = 723 * 128
PITCH_TABLE_BASE64 = "AAA7AHYAsgDtACgBZAGfAdsBFwJSAo4CygIFA0EDfQO5A/UDMQRuBKoE5gQiBV8FmwXYBRQGUQaNBsoGBwdDB4AHvQf6BzcIdAixCO8ILAlpCacJ5AkhCl8KnAraChgLVguTC9ELDwxNDIsMyQwHDUUNhA3CDQAOPw59DrwO+g45D3gPtg/1DzQQcxCyEPEQMBFvEa4R7hEtEmwSrBLrEisTaxOqE+oTKhRqFKkU6RQpFWkVqhXqFSoWaharFusWLBdsF60X7RcuGG8YsBjwGDEZchmzGfUZNhp3Grga+ho7G30bvhsAHEEcgxzFHAcdSB2KHcwdDh5RHpMe1R4XH1ofnB/fHyEgZCCmIOkgLCFvIbIh9SE4InsiviIBI0QjiCPLIw4kUiSWJNkkHSVhJaQl6CUsJnAmtCb4Jj0ngSfFJwooTiiSKNcoHClgKaUp6ikvKnQquSr+KkMriCvNKxMsWCydLOMsKC1uLbQt+S0/LoUuyy4RL1cvnS/jLyowcDC2MP0wQzGKMdAxFzJeMqUy7DIyM3kzwTMINE80ljTdNCU1bDW0Nfs1QzaLNtM2GjdiN6o38jc6OIM4yzgTOVw5pDntOTU6fjrGOg87WDuhO+o7Mzx8PMU8Dj1YPaE96j00Pn0+xz4RP1o/pD/uPzhAgkDMQBZBYUGrQfVBQEKKQtVCH0NqQ7VDAERLRJVE4UQsRXdFwkUNRllGpEbwRjtHh0fTRx5Iaki2SAJJTkmaSeZJM0p/SstKGEtkS7FL/ktKTJdM5EwxTX5Ny00YTmZOs04AT05Pm0/pTzZQhFDSUCBRblG8UQpSWFKmUvRSQ1ORU+BTLlR9VMxUGlVpVbhVB1ZWVqVW9FZEV5NX4lcyWIJY0VghWXFZwVkQWmBasFoBW1FboVvxW0JcklzjXDRdhF3VXSZed17IXhlfal+7Xw1gXmCwYAFhU2GkYfZhSGKaYuxiPmOQY+JjNGSHZNlkLGV+ZdFlJGZ2ZslmHGdvZ8JnFWhpaLxoD2ljabZpCmpearFqBWtZa61rAWxVbKps/mxSbadt+21QbqRu+W5Ob6Nv+G9NcKJw93BNcaJx93FNcqJy+HJOc6Rz+nNQdKZ0/HRSdah1/3VVdqx2AndZd7B3B3heeLR4DHljebp5EXppesB6GHtve8d7H3x3fM98J31/fdd9L36IfuB+OH+Rf+p/QoCbgPSATYGmgf+BWYKygguDZYO+gxiEcoTLhCWFf4XZhTOGjobohkKHnYf3h1KIrIgHiWKJvYkYinOKzooqi4WL4Is8jJeM84xPjauNB45jjr+OG493j9SPMJCMkOmQRpGikf+RXJK5khaTc5PRky6UjJTplEeVpJUClmCWvpYcl3qX2Jc2mJWY85hSmbCZD5pums2aLJuLm+qbSZyonAidZ53HnSaehp7mnkafpp8GoGagxqAnoYeh6KFIoqmiCqNro8yjLaSOpO+kUKWypROmdabWpjinmqf8p16owKgiqYSp56lJqqyqDqtxq9SrN6yarP2sYK3DrSeuiq7trlGvta8ZsHyw4LBFsamxDbJxstayOrOfswO0aLTNtDK1l7X8tWK2x7Yst5K397dduMO4KbmPufW5W7rBuii7jrv1u1u8wrwpvZC9971evsW+LL+Uv/u/Y8DKwDLBmsECwmrC0sI6w6LDC8RzxNzERMWtxRbGf8boxlHHu8ckyI3I98hgycrJNMqeygjLcsvcy0fMscwbzYbN8c1bzsbOMc+czwjQc9De0ErRtdEh0o3S+NJk09DTPdSp1BXVgtXu1VvWx9Y016HXDth72OnYVtnD2THantoM23rb6NtW3MTcMt2g3Q/efd7s3lvfyd844KfgFuGG4fXhZOLU4kPjs+Mj5JPkA+Vz5ePlVObE5jXnpecW6Ifo+Ohp6drpS+q86i7rn+sR7IPs9exm7dntS+697i/vou8U8Ifw+vBt8eDxU/LG8jnzrfMg9JT0B/V79e/1Y/bX9kz3wPc0+Kn4HvmS+Qf6fPrx+mb73PtR/Mf8PP2y/Sj+nv4U/4r/"
VOLUME_TABLE_BASE64 = "AAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBQUFBQUFBQUFBQUFBQUFBQUGBgYGBgYGBgYGBgYGBgYHBwcHBwcHBwcHBwcICAgICAgICAgICAkJCQkJCQkJCQkKCgoKCgoKCgsLCwsLCwsLDAwMDAwMDAwNDQ0NDQ0ODg4ODg4ODw8PDw8QEBAQEBARERERERISEhISExMTExQUFBQUFRUVFRYWFhYXFxcYGBgYGRkZGRoaGhsbGxwcHB0dHR4eHh8fHyAgICEhIiIiIyMkJCQlJSYmJycnKCgpKSoqKyssLC0tLi4vLzAxMTIyMzM0NTU2Njc4ODk6Ojs8PD0+Pz9AQUJCQ0RFRUZHSElKSktMTU5PUFFSUlNUVVZXWFlaW11eX2BhYmNkZWdoaWprbW5vcXJzdXZ3eXp7fX5/ICEhISIiIyMjJCQlJSYmJicnKCgpKSoqKyssLC0tLi4vLzAwMTEyMzM0NDU2Njc3ODk5Ojs7PD0+Pj9AQEFCQ0NERUZHR0hJSktMTU1OT1BRUlNUVVZXWFlaW1xdXl9gYmNkZWZnaWprbG1vcHFzdHV3eHl7fH5+QEFCQ0NERUZHR0hJSktMTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJkZWZnaGlrbG1ucHFydHV2eHl7fH1+QEFCQkNERUZGR0hJSktLTE1OT1BRUlNUVVZXWFlaW1xdXl9gYWJjZWZnaGlqbG1ub3Fyc3V2d3l6fH1+fw=="


def decode_u16_table(encoded: str) -> Tuple[int, ...]:
    payload = base64.b64decode(encoded.encode("ascii"))
    return struct.unpack("<" + ("H" * (len(payload) // 2)), payload)


def decode_u8_table(encoded: str) -> Tuple[int, ...]:
    return tuple(base64.b64decode(encoded.encode("ascii")))


PITCH_TABLE = decode_u16_table(PITCH_TABLE_BASE64)
VOLUME_TABLE = decode_u8_table(VOLUME_TABLE_BASE64)


@dataclass
class TrackRenderState:
    track_number: int
    event_index: int
    wait_ticks: int = 0
    call_stack: List[int] = field(default_factory=list)
    ended: bool = False
    instrument_id: int = 0
    transpose: int = 0
    track_volume: int = 64
    expression: int = 127
    pan: int = 64
    mono: bool = False
    track_priority: int = 64
    pitch_bend: int = 0
    pitch_bend_range: int = 2
    vibrato_depth: int = 0
    vibrato_speed: int = 16
    vibrato_range: int = 1
    vibrato_delay: int = 10
    vibrato_type: Optional[int] = 0
    attack_rate: Optional[int] = None
    decay_rate: Optional[int] = None
    sustain_rate: Optional[int] = None
    release_rate: Optional[int] = None


@dataclass
class RenderedNote:
    track_number: int
    instrument_id: int
    note_definition: ndspy.soundBank.NoteDefinition
    pitch: int
    velocity: int
    start_tick: int
    end_tick: int
    track_volume: int
    expression: int
    pan: int
    track_priority: int
    pitch_bend: int
    pitch_bend_range: int
    vibrato_depth: int
    vibrato_speed: int
    vibrato_range: int
    vibrato_delay: int
    vibrato_type: Optional[int]
    attack_rate: Optional[int]
    decay_rate: Optional[int]
    sustain_rate: Optional[int]
    release_rate: Optional[int]


@dataclass(frozen=True)
class TrackDynamicState:
    tick: int
    track_volume: int
    expression: int
    pan: int
    track_priority: int
    pitch_bend: int
    pitch_bend_range: int
    vibrato_depth: int
    vibrato_speed: int
    vibrato_range: int
    vibrato_delay: int
    vibrato_type: Optional[int]


@dataclass
class NoteChannelAllocation:
    channel: Optional[int]
    start_sample: int
    end_sample: int
    dropped_by_channel_limit: bool = False


@dataclass
class ActiveChannelAllocation:
    note_index: int
    channel: int
    track_priority: int
    start_sample: int
    end_sample: int


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def clamp_int(value: int, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, value))


def signed_byte(value: int) -> int:
    return value - 256 if value >= 128 else value


def _pcm8_samples(data: bytes, total_length: int, loop_offset: int) -> Tuple[List[float], int]:
    byte_count = min(len(data), total_length * 4 if total_length > 0 else len(data))
    samples = [((byte - 256) if byte >= 128 else byte) / 128.0 for byte in data[:byte_count]]
    return samples, clamp_int(loop_offset * 4, 0, len(samples))


def _pcm16_samples(data: bytes, total_length: int, loop_offset: int) -> Tuple[List[float], int]:
    byte_count = min(len(data), total_length * 4 if total_length > 0 else len(data))
    byte_count -= byte_count % 2
    samples = [
        struct.unpack_from("<h", data, offset)[0] / 32768.0
        for offset in range(0, byte_count, 2)
    ]
    return samples, clamp_int(loop_offset * 2, 0, len(samples))


def _adpcm_samples(data: bytes, total_length: int, loop_offset: int) -> Tuple[List[float], int]:
    if len(data) < 4:
        return [], 0

    header = struct.unpack_from("<I", data, 0)[0]
    predictor = struct.unpack_from("<h", data, 0)[0]
    step_index = clamp_int((header >> 16) & 0x7F, 0, len(IMA_STEP_TABLE) - 1)
    samples = [predictor / 32768.0]

    for byte in data[4:]:
        for nibble in (byte & 0x0F, (byte >> 4) & 0x0F):
            step = IMA_STEP_TABLE[step_index]
            diff = step >> 3
            if nibble & 0x1:
                diff += step >> 2
            if nibble & 0x2:
                diff += step >> 1
            if nibble & 0x4:
                diff += step
            if nibble & 0x8:
                predictor -= diff
            else:
                predictor += diff

            predictor = clamp_int(predictor, -32768, 32767)
            step_index = clamp_int(step_index + IMA_INDEX_TABLE[nibble], 0, len(IMA_STEP_TABLE) - 1)
            samples.append(predictor / 32768.0)

    if total_length > 0:
        expected_samples = 1 + (max(0, total_length - 1) * 8)
        if expected_samples < len(samples):
            samples = samples[:expected_samples]

    loop_sample = 1 + (max(0, loop_offset - 1) * 8)
    return samples, clamp_int(loop_sample, 0, len(samples))


def decode_swav_samples(swav) -> Tuple[List[float], int]:
    if swav.waveType == ndspy.soundWave.WaveType.PCM8:
        return _pcm8_samples(swav.data, swav.totalLength, swav.loopOffset)
    if swav.waveType == ndspy.soundWave.WaveType.PCM16:
        return _pcm16_samples(swav.data, swav.totalLength, swav.loopOffset)
    if swav.waveType == ndspy.soundWave.WaveType.ADPCM:
        return _adpcm_samples(swav.data, swav.totalLength, swav.loopOffset)
    raise ValueError(f"Unsupported SWAV type: {swav.waveType}")


def resolve_note_definition(instrument, pitch: int) -> ndspy.soundBank.NoteDefinition:
    if isinstance(instrument, ndspy.soundBank.SingleNoteInstrument):
        return instrument.noteDefinition
    if isinstance(instrument, ndspy.soundBank.RangeInstrument):
        index = clamp_int(pitch - instrument.firstPitch, 0, len(instrument.noteDefinitions) - 1)
        return instrument.noteDefinitions[index]
    if isinstance(instrument, ndspy.soundBank.RegionalInstrument):
        for region in instrument.regions:
            if pitch <= region.lastPitch:
                return region.noteDefinition
        return instrument.regions[-1].noteDefinition
    raise ValueError(f"Unsupported instrument type: {type(instrument).__name__}")


def duty_cycle_for_square(duty_value: int) -> float:
    duty_lut = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 0.0]
    return duty_lut[duty_value & 0x7]


def pitch_ratio(target_pitch: float, root_pitch: float) -> float:
    return 2.0 ** ((target_pitch - root_pitch) / 12.0)


def pitch_bend_semitones(pitch_bend: int, pitch_bend_range: int) -> float:
    return (pitch_bend * pitch_bend_range) / 128.0


def cnv_attk(raw_value: int) -> int:
    lut = (
        0x00, 0x01, 0x05, 0x0E, 0x1A, 0x26, 0x33, 0x3F, 0x49, 0x54,
        0x5C, 0x64, 0x6D, 0x74, 0x7B, 0x7F, 0x84, 0x89, 0x8F,
    )
    if raw_value >= 0x6D:
        return lut[0x7F - raw_value]
    return 0xFF - raw_value


def cnv_fall(raw_value: int) -> int:
    if raw_value == 0x7F:
        return 0xFFFF
    if raw_value == 0x7E:
        return 0x3C00
    if raw_value < 0x32:
        return ((raw_value << 1) + 1) & 0xFFFF
    return (0x1E00 // (0x7E - raw_value)) & 0xFFFF


def cnv_sust(raw_value: int) -> int:
    lut = (
        0xFD2D, 0xFD2E, 0xFD2F, 0xFD75, 0xFDA7, 0xFDCE, 0xFDEE, 0xFE09, 0xFE20, 0xFE34, 0xFE46, 0xFE57, 0xFE66, 0xFE74, 0xFE81, 0xFE8D,
        0xFE98, 0xFEA3, 0xFEAD, 0xFEB6, 0xFEBF, 0xFEC7, 0xFECF, 0xFED7, 0xFEDF, 0xFEE6, 0xFEEC, 0xFEF3, 0xFEF9, 0xFEFF, 0xFF05, 0xFF0B,
        0xFF11, 0xFF16, 0xFF1B, 0xFF20, 0xFF25, 0xFF2A, 0xFF2E, 0xFF33, 0xFF37, 0xFF3C, 0xFF40, 0xFF44, 0xFF48, 0xFF4C, 0xFF50, 0xFF53,
        0xFF57, 0xFF5B, 0xFF5E, 0xFF62, 0xFF65, 0xFF68, 0xFF6B, 0xFF6F, 0xFF72, 0xFF75, 0xFF78, 0xFF7B, 0xFF7E, 0xFF81, 0xFF83, 0xFF86,
        0xFF89, 0xFF8C, 0xFF8E, 0xFF91, 0xFF93, 0xFF96, 0xFF99, 0xFF9B, 0xFF9D, 0xFFA0, 0xFFA2, 0xFFA5, 0xFFA7, 0xFFA9, 0xFFAB, 0xFFAE,
        0xFFB0, 0xFFB2, 0xFFB4, 0xFFB6, 0xFFB8, 0xFFBA, 0xFFBC, 0xFFBE, 0xFFC0, 0xFFC2, 0xFFC4, 0xFFC6, 0xFFC8, 0xFFCA, 0xFFCC, 0xFFCE,
        0xFFCF, 0xFFD1, 0xFFD3, 0xFFD5, 0xFFD6, 0xFFD8, 0xFFDA, 0xFFDC, 0xFFDD, 0xFFDF, 0xFFE1, 0xFFE2, 0xFFE4, 0xFFE5, 0xFFE7, 0xFFE9,
        0xFFEA, 0xFFEC, 0xFFED, 0xFFEF, 0xFFF0, 0xFFF2, 0xFFF3, 0xFFF5, 0xFFF6, 0xFFF8, 0xFFF9, 0xFFFA, 0xFFFC, 0xFFFD, 0xFFFF, 0x0000,
    )
    if raw_value == 0x7F:
        return 0
    return -((0x10000 - lut[raw_value]) << 7)


def adjust_freq(base_frequency: int, pitch_units: int) -> int:
    shift = 0
    pitch_units = -pitch_units
    while pitch_units < 0:
        shift -= 1
        pitch_units += 0x300
    while pitch_units >= 0x300:
        shift += 1
        pitch_units -= 0x300

    frequency = base_frequency * (PITCH_TABLE[pitch_units] + 0x10000)
    shift -= 16
    if shift <= 0:
        frequency >>= -shift
    elif shift < 32:
        if frequency & ((~0) << (32 - shift)):
            return 0xFFFF
        frequency <<= shift
    else:
        return 0x10

    if frequency < 0x10:
        return 0x10
    if frequency > 0xFFFF:
        return 0xFFFF
    return frequency


def pitch_units_for(note_pitch: int, root_pitch: int, pitch_bend: int, pitch_bend_range: int, modulation_units: int = 0) -> int:
    bend_units = (pitch_bend * pitch_bend_range) >> 1
    return ((note_pitch - root_pitch) * 64) + bend_units + modulation_units


def volume_gain(master_volume: int, track_volume: int, expression: int, velocity: int, amplitude: int, modulation_units: int = 0) -> float:
    total_volume = (cnv_sust(master_volume) >> 7)
    total_volume += (cnv_sust(track_volume) >> 7)
    total_volume += (cnv_sust(expression) >> 7)
    total_volume += (cnv_sust(velocity) >> 7)
    total_volume += amplitude >> 7
    total_volume += modulation_units
    if total_volume > 0:
        total_volume = 0
    total_volume += 723
    if total_volume <= 0:
        return 0.0
    total_volume = clamp_int(total_volume, 0, len(VOLUME_TABLE) - 1)
    divider = 1
    if total_volume < (723 - 240):
        divider = 16
    elif total_volume < (723 - 120):
        divider = 4
    elif total_volume < (723 - 60):
        divider = 2
    return (VOLUME_TABLE[total_volume] / divider) / 127.0


def dynamic_state_at_time(
    track_dynamic_states: List[TrackDynamicState],
    current_tick: int,
    tick_times: List[float],
    sample_time: float,
) -> Tuple[int, TrackDynamicState]:
    while current_tick + 1 < len(track_dynamic_states) and tick_times[current_tick + 1] <= sample_time:
        current_tick += 1
    return current_tick, track_dynamic_states[min(current_tick, len(track_dynamic_states) - 1)]


def estimate_release_seconds(release_raw: int) -> float:
    amplitude = 0
    release_rate = cnv_fall(release_raw)
    cycles = 0
    while amplitude > -ADSR_THRESHOLD:
        amplitude -= release_rate
        cycles += 1
        if cycles > 4096:
            break
    return cycles * SEQUENCE_TIMER_SECONDS


def note_velocity_gain(sequence_volume: int, track_volume: int, expression: int, velocity: int) -> float:
    return (
        clamp(sequence_volume / 127.0, 0.0, 1.0)
        * clamp(track_volume / 127.0, 0.0, 1.0)
        * clamp(expression / 127.0, 0.0, 1.0)
        * clamp(velocity / 127.0, 0.0, 1.0)
    )


def note_pan(track_pan: int, note_pan: int) -> Tuple[float, float]:
    pan_value = clamp(((track_pan - 64) + (note_pan - 64)) + 64, 0, 127)
    right = pan_value / 127.0
    left = 1.0 - right
    return left, right


def current_track_dynamic_state(track: TrackRenderState, tick: int) -> TrackDynamicState:
    return TrackDynamicState(
        tick=tick,
        track_volume=track.track_volume,
        expression=track.expression,
        pan=track.pan,
        track_priority=track.track_priority,
        pitch_bend=track.pitch_bend,
        pitch_bend_range=track.pitch_bend_range,
        vibrato_depth=track.vibrato_depth,
        vibrato_speed=track.vibrato_speed,
        vibrato_range=track.vibrato_range,
        vibrato_delay=track.vibrato_delay,
        vibrato_type=track.vibrato_type,
    )


def record_track_dynamic_state(
    timelines: Dict[int, List[TrackDynamicState]],
    track: TrackRenderState,
    tick: int,
) -> None:
    timeline = timelines.setdefault(track.track_number, [])
    state = current_track_dynamic_state(track, tick)
    if timeline and timeline[-1].tick == tick:
        timeline[-1] = state
        return
    if timeline and timeline[-1] == state:
        return
    timeline.append(state)


def note_envelope_seconds(raw_value: int, fast_limit: float, slow_limit: float) -> float:
    normalized = 1.0 - clamp(raw_value / 127.0, 0.0, 1.0)
    return fast_limit + ((normalized * normalized) * (slow_limit - fast_limit))


def player_allocatable_channels(archive, player_id: int) -> List[int]:
    if 0 <= player_id < len(archive.sequencePlayers):
        _, sequence_player = archive.sequencePlayers[player_id]
        if sequence_player is not None and sequence_player.channels:
            return sorted(sequence_player.channels)
    return list(range(16))


def compatible_channels_for_note(note_definition: ndspy.soundBank.NoteDefinition, allocatable_channels: List[int]) -> List[int]:
    note_type = note_definition.type
    if note_type == ndspy.soundBank.NoteType.PCM:
        return list(allocatable_channels)
    if note_type == ndspy.soundBank.NoteType.PSG_SQUARE_WAVE:
        return [channel for channel in allocatable_channels if 8 <= channel <= 13]
    if note_type == ndspy.soundBank.NoteType.PSG_WHITE_NOISE:
        return [channel for channel in allocatable_channels if channel in (14, 15)]
    return []


def preferred_channel_order(note_definition: ndspy.soundBank.NoteDefinition, allocatable_channels: List[int]) -> List[int]:
    return compatible_channels_for_note(note_definition, allocatable_channels)


def note_envelope_parameters(note: RenderedNote) -> Tuple[int, int, int, int]:
    attack_raw = note.attack_rate if note.attack_rate is not None else note.note_definition.attack
    decay_raw = note.decay_rate if note.decay_rate is not None else note.note_definition.decay
    sustain_raw = note.sustain_rate if note.sustain_rate is not None else note.note_definition.sustain
    release_raw = note.release_rate if note.release_rate is not None else note.note_definition.release
    return (
        cnv_attk(attack_raw),
        cnv_fall(decay_raw),
        cnv_sust(sustain_raw),
        cnv_fall(release_raw),
    )


def envelope_amplitude_at_sample(
    note: RenderedNote,
    sample_index: int,
    output_rate: int,
    tick_times: List[float],
) -> int:
    start_time = tick_times[note.start_tick]
    end_time = tick_times[note.end_tick]
    sample_time = sample_index / output_rate
    if sample_time <= start_time:
        return -ADSR_THRESHOLD

    attack_rate, decay_rate, sustain_level, release_rate = note_envelope_parameters(note)
    amplitude = -ADSR_THRESHOLD
    state = "start"
    next_control_time = start_time + SEQUENCE_TIMER_SECONDS

    while next_control_time <= sample_time:
        if next_control_time >= end_time and state not in ("release", "done"):
            state = "release"

        if state == "start":
            amplitude = -ADSR_THRESHOLD
            state = "attack"
        if state == "attack":
            amplitude = (attack_rate * amplitude) // 255
            if amplitude == 0:
                state = "decay"
        elif state == "decay":
            amplitude -= decay_rate
            if amplitude <= sustain_level:
                amplitude = sustain_level
                state = "sustain"
        elif state == "release":
            amplitude -= release_rate
            if amplitude <= -ADSR_THRESHOLD:
                amplitude = -ADSR_THRESHOLD
                state = "done"
                break

        next_control_time += SEQUENCE_TIMER_SECONDS

    return amplitude


def allocate_note_channels(
    rendered_note_metadata,
    output_rate: int,
    tick_times: List[float],
    allocatable_channels: List[int],
) -> List[NoteChannelAllocation]:
    allocations: List[Optional[NoteChannelAllocation]] = [None] * len(rendered_note_metadata)
    queue = []
    note_logical_end_samples: List[int] = [0] * len(rendered_note_metadata)
    for note_index, (note, _waveform_kind, _waveform_payload, release_seconds) in enumerate(rendered_note_metadata):
        start_time = tick_times[note.start_tick]
        logical_end_time = tick_times[note.end_tick]
        end_time = logical_end_time + release_seconds
        note_logical_end_samples[note_index] = int(logical_end_time * output_rate)
        queue.append(
            (
                int(start_time * output_rate),
                -note.track_priority,
                note.track_number,
                note_index,
                int(end_time * output_rate) + 1,
            )
        )

    active_allocations: List[ActiveChannelAllocation] = []
    for start_sample, _neg_priority, track_number, note_index, natural_end_sample in sorted(queue):
        active_allocations = [
            allocation
            for allocation in active_allocations
            if allocation.end_sample > start_sample
        ]
        note, _waveform_kind, _waveform_payload, _release_seconds = rendered_note_metadata[note_index]
        preferred_channels = preferred_channel_order(note.note_definition, allocatable_channels)
        if not preferred_channels:
            allocations[note_index] = NoteChannelAllocation(
                channel=None,
                start_sample=start_sample,
                end_sample=start_sample,
                dropped_by_channel_limit=True,
            )
            continue

        used_channels = {allocation.channel for allocation in active_allocations}
        free_channel = next((channel for channel in preferred_channels if channel not in used_channels), None)
        if free_channel is not None:
            allocations[note_index] = NoteChannelAllocation(
                channel=free_channel,
                start_sample=start_sample,
                end_sample=natural_end_sample,
            )
            active_allocations.append(
                ActiveChannelAllocation(
                    note_index=note_index,
                    channel=free_channel,
                    track_priority=note.track_priority,
                    start_sample=start_sample,
                    end_sample=natural_end_sample,
                )
            )
            continue

        release_candidates = [
            allocation
            for allocation in active_allocations
            if allocation.channel in preferred_channels and start_sample >= note_logical_end_samples[allocation.note_index]
        ]
        if release_candidates:
            released = min(
                release_candidates,
                key=lambda allocation: (
                    envelope_amplitude_at_sample(
                        rendered_note_metadata[allocation.note_index][0],
                        start_sample,
                        output_rate,
                        tick_times,
                    ),
                    allocation.channel,
                ),
            )
            previous_allocation = allocations[released.note_index]
            if previous_allocation is not None:
                previous_allocation.end_sample = start_sample

            active_allocations = [
                allocation
                for allocation in active_allocations
                if allocation.note_index != released.note_index
            ]
            allocations[note_index] = NoteChannelAllocation(
                channel=released.channel,
                start_sample=start_sample,
                end_sample=natural_end_sample,
            )
            active_allocations.append(
                ActiveChannelAllocation(
                    note_index=note_index,
                    channel=released.channel,
                    track_priority=note.track_priority,
                    start_sample=start_sample,
                    end_sample=natural_end_sample,
                )
            )
            continue

        stealable = [
            allocation
            for allocation in active_allocations
            if allocation.channel in preferred_channels and allocation.track_priority < note.track_priority
        ]
        if not stealable:
            allocations[note_index] = NoteChannelAllocation(
                channel=None,
                start_sample=start_sample,
                end_sample=start_sample,
                dropped_by_channel_limit=True,
            )
            continue

        stolen = next(
            allocation
            for channel in preferred_channels
            for allocation in active_allocations
            if allocation.channel == channel and allocation.track_priority < note.track_priority
        )
        previous_allocation = allocations[stolen.note_index]
        if previous_allocation is not None:
            previous_allocation.end_sample = start_sample

        active_allocations = [
            allocation
            for allocation in active_allocations
            if allocation.note_index != stolen.note_index
        ]
        allocations[note_index] = NoteChannelAllocation(
            channel=stolen.channel,
            start_sample=start_sample,
            end_sample=natural_end_sample,
        )
        active_allocations.append(
            ActiveChannelAllocation(
                note_index=note_index,
                channel=stolen.channel,
                track_priority=note.track_priority,
                start_sample=start_sample,
                end_sample=natural_end_sample,
            )
        )

    return [
        allocation
        if allocation is not None else NoteChannelAllocation(channel=None, start_sample=0, end_sample=0, dropped_by_channel_limit=True)
        for allocation in allocations
    ]


def get_sound_sine(argument: int) -> int:
    lut_size = len(SOUND_SINE_LUT) - 1
    if argument < lut_size:
        return SOUND_SINE_LUT[argument]
    if argument < (2 * lut_size):
        return SOUND_SINE_LUT[(2 * lut_size) - argument]
    if argument < (3 * lut_size):
        return -SOUND_SINE_LUT[argument - (2 * lut_size)]
    return -SOUND_SINE_LUT[(4 * lut_size) - argument]


def note_type_name(note_definition: ndspy.soundBank.NoteDefinition) -> str:
    note_type = note_definition.type
    return note_type.name if hasattr(note_type, "name") else str(note_type)


def waveform_trace_details(
    note_definition: ndspy.soundBank.NoteDefinition,
    bank,
) -> Dict[str, Optional[Union[int, bool]]]:
    details: Dict[str, Optional[Union[int, bool]]] = {
        "waveArchiveSlot": None,
        "waveArchiveID": None,
        "waveID": None,
        "isLooped": None,
    }
    if note_definition.type != ndspy.soundBank.NoteType.PCM:
        return details

    details["waveArchiveSlot"] = note_definition.waveArchiveIDID
    if note_definition.waveArchiveIDID < len(bank.waveArchiveIDs):
        details["waveArchiveID"] = bank.waveArchiveIDs[note_definition.waveArchiveIDID]
    details["waveID"] = note_definition.waveID
    return details


def render_sequence_audio(args: argparse.Namespace) -> None:
    archive_path = Path(args.input)
    output_wav = Path(args.output_wav)
    output_json = Path(args.output_json) if args.output_json else None
    output_wav.parent.mkdir(parents=True, exist_ok=True)
    if output_json is not None:
        output_json.parent.mkdir(parents=True, exist_ok=True)

    archive = ndspy.soundArchive.SDAT(archive_path.read_bytes())
    matched_index = None
    matched_sequence = None
    for index, (name, sequence) in enumerate(archive.sequences):
        if name == args.cue_name:
            matched_index = index
            matched_sequence = sequence
            break

    if matched_sequence is None:
        raise ValueError(f"Could not find sequence '{args.cue_name}' in {archive_path}")

    matched_sequence.parse()
    bank = archive.banks[matched_sequence.bankID][1]
    if bank is None:
        raise ValueError(f"Sequence '{args.cue_name}' references missing bank {matched_sequence.bankID}")

    events = matched_sequence.events
    event_to_index = {event: index for index, event in enumerate(events)}
    track_states: Dict[int, TrackRenderState] = {0: TrackRenderState(track_number=0, event_index=0)}
    track_dynamic_timelines: Dict[int, List[TrackDynamicState]] = {0: [current_track_dynamic_state(track_states[0], 0)]}
    rendered_notes: List[RenderedNote] = []
    pitch_vibrato_type = int(ndspy.soundSequence.VibratoTypeSequenceEvent.Value.PITCH)

    tempo = 120
    current_tick = 0
    tick_times = [0.0]

    def spawn_track(track_number: int, first_event) -> None:
        if track_number in track_states or first_event not in event_to_index:
            return
        track_states[track_number] = TrackRenderState(
            track_number=track_number,
            event_index=event_to_index[first_event],
        )
        track_dynamic_timelines[track_number] = [current_track_dynamic_state(track_states[track_number], current_tick)]

    def process_track(track: TrackRenderState) -> None:
        nonlocal tempo

        while not track.ended and track.wait_ticks == 0:
            if track.event_index >= len(events):
                track.ended = True
                return

            event = events[track.event_index]
            track.event_index += 1

            if isinstance(event, ndspy.soundSequence.DefineTracksSequenceEvent):
                continue
            if isinstance(event, ndspy.soundSequence.BeginTrackSequenceEvent):
                spawn_track(event.trackNumber, event.firstEvent)
                continue
            if isinstance(event, ndspy.soundSequence.InstrumentSwitchSequenceEvent):
                track.instrument_id = event.instrumentID
                continue
            if isinstance(event, ndspy.soundSequence.TrackVolumeSequenceEvent):
                track.track_volume = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.ExpressionSequenceEvent):
                track.expression = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.PanSequenceEvent):
                track.pan = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.TrackPrioritySequenceEvent):
                track.track_priority = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.TransposeSequenceEvent):
                track.transpose = event.value
                continue
            if isinstance(event, ndspy.soundSequence.MonoPolySequenceEvent):
                track.mono = event.value == ndspy.soundSequence.MonoPolySequenceEvent.Value.MONO
                continue
            if isinstance(event, ndspy.soundSequence.PortamentoSequenceEvent):
                track.pitch_bend = signed_byte(event.value)
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.PortamentoRangeSequenceEvent):
                track.pitch_bend_range = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.VibratoDepthSequenceEvent):
                track.vibrato_depth = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.VibratoSpeedSequenceEvent):
                track.vibrato_speed = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.VibratoRangeSequenceEvent):
                track.vibrato_range = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.VibratoDelaySequenceEvent):
                track.vibrato_delay = event.value
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.VibratoTypeSequenceEvent):
                track.vibrato_type = int(event.value)
                record_track_dynamic_state(track_dynamic_timelines, track, current_tick)
                continue
            if isinstance(event, ndspy.soundSequence.AttackRateSequenceEvent):
                track.attack_rate = event.value
                continue
            if isinstance(event, ndspy.soundSequence.DecayRateSequenceEvent):
                track.decay_rate = event.value
                continue
            if isinstance(event, ndspy.soundSequence.SustainRateSequenceEvent):
                track.sustain_rate = event.value
                continue
            if isinstance(event, ndspy.soundSequence.ReleaseRateSequenceEvent):
                track.release_rate = event.value
                continue
            if isinstance(event, ndspy.soundSequence.TempoSequenceEvent):
                tempo = event.value
                continue
            if isinstance(event, ndspy.soundSequence.CallSequenceEvent):
                track.call_stack.append(track.event_index)
                track.event_index = event_to_index[event.destination]
                continue
            if isinstance(event, ndspy.soundSequence.ReturnSequenceEvent):
                if track.call_stack:
                    track.event_index = track.call_stack.pop()
                else:
                    track.ended = True
                continue
            if isinstance(event, ndspy.soundSequence.EndTrackSequenceEvent):
                track.ended = True
                return
            if isinstance(event, ndspy.soundSequence.RestSequenceEvent):
                track.wait_ticks = max(0, event.duration)
                return
            if isinstance(event, ndspy.soundSequence.NoteSequenceEvent):
                if track.mono:
                    for note in reversed(rendered_notes):
                        if note.track_number == track.track_number and note.end_tick > current_tick:
                            note.end_tick = current_tick
                            break
                instrument = bank.instruments[track.instrument_id]
                note_definition = resolve_note_definition(instrument, event.pitch + track.transpose)
                rendered_notes.append(
                    RenderedNote(
                        track_number=track.track_number,
                        instrument_id=track.instrument_id,
                        note_definition=note_definition,
                        pitch=event.pitch + track.transpose,
                        velocity=event.velocity,
                        start_tick=current_tick,
                        end_tick=current_tick + max(1, event.duration),
                        track_volume=track.track_volume,
                        expression=track.expression,
                        pan=track.pan,
                        track_priority=track.track_priority,
                        pitch_bend=track.pitch_bend,
                        pitch_bend_range=track.pitch_bend_range,
                        vibrato_depth=track.vibrato_depth,
                        vibrato_speed=track.vibrato_speed,
                        vibrato_range=track.vibrato_range,
                        vibrato_delay=track.vibrato_delay,
                        vibrato_type=track.vibrato_type,
                        attack_rate=track.attack_rate,
                        decay_rate=track.decay_rate,
                        sustain_rate=track.sustain_rate,
                        release_rate=track.release_rate,
                    )
                )
                continue
            if isinstance(event, ndspy.soundSequence.RawDataSequenceEvent):
                track.ended = True
                return

    sequence_cycle_accumulator = 0
    current_time = 0.0

    while True:
        while any(not track.ended and track.wait_ticks == 0 for track in track_states.values()):
            for track_number in sorted(track_states.keys()):
                track = track_states[track_number]
                if not track.ended and track.wait_ticks == 0:
                    process_track(track)

        if all(track.ended for track in track_states.values()):
            break

        current_time += SEQUENCE_TIMER_SECONDS
        sequence_cycle_accumulator += tempo
        while sequence_cycle_accumulator >= SEQUENCE_TICK_THRESHOLD:
            sequence_cycle_accumulator -= SEQUENCE_TICK_THRESHOLD
            current_tick += 1
            tick_times.append(current_time)
            for track in track_states.values():
                if track.wait_ticks > 0:
                    track.wait_ticks -= 1

    audible_notes = [note for note in rendered_notes if note.velocity > 0]
    max_note_end_tick = max((note.end_tick for note in audible_notes), default=current_tick)
    while len(tick_times) <= max_note_end_tick:
        current_time += SEQUENCE_TIMER_SECONDS
        sequence_cycle_accumulator += tempo
        while sequence_cycle_accumulator >= SEQUENCE_TICK_THRESHOLD and len(tick_times) <= max_note_end_tick:
            sequence_cycle_accumulator -= SEQUENCE_TICK_THRESHOLD
            tick_times.append(current_time)

    waveform_cache: Dict[Tuple[int, int], Tuple[List[float], int, int, int, bool]] = {}
    dense_track_dynamic_states: Dict[int, List[TrackDynamicState]] = {}
    for track_number, timeline in track_dynamic_timelines.items():
        if not timeline:
            continue
        dense_states: List[TrackDynamicState] = []
        current_state_index = 0
        current_state = timeline[0]
        for tick in range(max_note_end_tick + 1):
            while current_state_index + 1 < len(timeline) and timeline[current_state_index + 1].tick <= tick:
                current_state_index += 1
                current_state = timeline[current_state_index]
            dense_states.append(current_state)
        dense_track_dynamic_states[track_number] = dense_states

    def waveform_for(note_definition: ndspy.soundBank.NoteDefinition) -> Tuple[str, Union[Tuple[List[float], int, int, int, bool], float]]:
        if note_definition.type == ndspy.soundBank.NoteType.PSG_SQUARE_WAVE:
            return "psg_square", duty_cycle_for_square(note_definition.waveID)

        if note_definition.type != ndspy.soundBank.NoteType.PCM:
            raise ValueError(f"Unsupported note definition type: {note_definition.type}")

        swar_slot = note_definition.waveArchiveIDID
        if swar_slot >= len(bank.waveArchiveIDs):
            raise ValueError(f"Invalid SWAR slot {swar_slot} for bank {matched_sequence.bankID}")
        real_swar_index = bank.waveArchiveIDs[swar_slot]
        cache_key = (real_swar_index, note_definition.waveID)
        if cache_key not in waveform_cache:
            swar = archive.waveArchives[real_swar_index][1]
            swav = swar.waves[note_definition.waveID]
            samples, loop_sample = decode_swav_samples(swav)
            waveform_cache[cache_key] = (samples, loop_sample, swav.sampleRate, swav.time, swav.isLooped)
        return "pcm", waveform_cache[cache_key]

    rendered_note_metadata = []
    output_rate = args.sample_rate
    max_end_time = tick_times[min(current_tick, len(tick_times) - 1)] if tick_times else 0.0
    for note in audible_notes:
        waveform_kind, waveform_payload = waveform_for(note.note_definition)
        release_raw = note.release_rate if note.release_rate is not None else note.note_definition.release
        release_seconds = estimate_release_seconds(release_raw)
        end_time = tick_times[note.end_tick] + release_seconds
        max_end_time = max(max_end_time, end_time)
        rendered_note_metadata.append((note, waveform_kind, waveform_payload, release_seconds))

    allocatable_channels = player_allocatable_channels(archive, matched_sequence.playerID)
    note_channel_allocations = allocate_note_channels(
        rendered_note_metadata,
        output_rate,
        tick_times,
        allocatable_channels,
    )

    sample_count = max(1, int(math.ceil(max_end_time * output_rate)))
    if args.target_duration_seconds is not None:
        max_end_time = max(max_end_time, args.target_duration_seconds)
        sample_count = max(sample_count, int(math.ceil(max_end_time * output_rate)))
    left_channel = [0.0] * sample_count
    right_channel = [0.0] * sample_count

    for note_index, (note, waveform_kind, waveform_payload, release_seconds) in enumerate(rendered_note_metadata):
        channel_allocation = note_channel_allocations[note_index]
        if channel_allocation.channel is None or channel_allocation.end_sample <= channel_allocation.start_sample:
            continue
        track_dynamic_states = dense_track_dynamic_states.get(note.track_number)
        if not track_dynamic_states:
            continue
        start_time = tick_times[note.start_tick]
        end_time = tick_times[note.end_tick]
        start_sample = max(int(start_time * output_rate), channel_allocation.start_sample)
        render_end_sample = min(
            sample_count,
            int((end_time + release_seconds) * output_rate) + 1,
            channel_allocation.end_sample,
        )

        attack_raw = note.attack_rate if note.attack_rate is not None else note.note_definition.attack
        decay_raw = note.decay_rate if note.decay_rate is not None else note.note_definition.decay
        sustain_raw = note.sustain_rate if note.sustain_rate is not None else note.note_definition.sustain
        attack_rate = cnv_attk(attack_raw)
        decay_rate = cnv_fall(decay_raw)
        sustain_level = cnv_sust(sustain_raw)
        release_rate = cnv_fall(note.release_rate if note.release_rate is not None else note.note_definition.release)

        if waveform_kind == "psg_square":
            duty_cycle = waveform_payload
            phase = 0.0
            channel_started = False
            envelope_state = "start"
            amplitude = -ADSR_THRESHOLD
            modulation_delay_count = 0
            modulation_counter = 0
            modulation_units = 0
            dynamic_tick = note.start_tick
            dynamic_state = track_dynamic_states[min(dynamic_tick, len(track_dynamic_states) - 1)]
            next_control_time = start_time + SEQUENCE_TIMER_SECONDS
            for sample_index in range(start_sample, render_end_sample):
                sample_time = sample_index / output_rate
                if sample_time >= end_time + release_seconds:
                    break

                while sample_time >= next_control_time:
                    dynamic_tick, dynamic_state = dynamic_state_at_time(
                        track_dynamic_states,
                        dynamic_tick,
                        tick_times,
                        next_control_time,
                    )
                    if modulation_delay_count < dynamic_state.vibrato_delay:
                        modulation_delay_count += 1
                        modulation_units = 0
                    elif dynamic_state.vibrato_depth > 0 and dynamic_state.vibrato_speed > 0 and dynamic_state.vibrato_range > 0:
                        speed = dynamic_state.vibrato_speed << 6
                        counter = (modulation_counter + speed) >> 8
                        while counter >= 0x80:
                            counter -= 0x80
                        modulation_counter += speed
                        modulation_counter &= 0xFF
                        modulation_counter |= counter << 8
                        modulation_units = (get_sound_sine(modulation_counter >> 8) * dynamic_state.vibrato_range * dynamic_state.vibrato_depth) >> 8
                    else:
                        modulation_units = 0
                    if sample_time >= end_time and envelope_state not in ("release", "done"):
                        envelope_state = "release"
                    if envelope_state == "start":
                        amplitude = -ADSR_THRESHOLD
                        envelope_state = "attack"
                        channel_started = True
                    if envelope_state == "attack":
                        amplitude = (attack_rate * amplitude) // 255
                        if amplitude == 0:
                            envelope_state = "decay"
                    elif envelope_state == "decay":
                        amplitude -= decay_rate
                        if amplitude <= sustain_level:
                            amplitude = sustain_level
                            envelope_state = "sustain"
                    elif envelope_state == "release":
                        amplitude -= release_rate
                        if amplitude <= -ADSR_THRESHOLD:
                            envelope_state = "done"
                    next_control_time += SEQUENCE_TIMER_SECONDS

                if not channel_started or envelope_state == "done":
                    continue

                pitch_units = pitch_units_for(note.pitch, 69, dynamic_state.pitch_bend, dynamic_state.pitch_bend_range)
                if dynamic_state.vibrato_type in (None, pitch_vibrato_type):
                    pitch_units += modulation_units
                timer_value = adjust_freq(int(ARM7_CLOCK / (440.0 * 8.0)), pitch_units)
                frequency = ARM7_CLOCK / max(1, timer_value) / 8.0
                phase += frequency / output_rate
                sample_value = 1.0 if (phase % 1.0) < duty_cycle else -1.0

                volume_modulation = modulation_units if dynamic_state.vibrato_type == 1 else 0
                pan_value = clamp_int(dynamic_state.pan + note.note_definition.pan - 64 + (modulation_units if dynamic_state.vibrato_type == 2 else 0), 0, 127)
                left_gain = 1.0 - (pan_value / 127.0)
                right_gain = pan_value / 127.0
                mixed = sample_value * volume_gain(
                    matched_sequence.volume,
                    dynamic_state.track_volume,
                    dynamic_state.expression,
                    note.velocity,
                    amplitude,
                    volume_modulation,
                ) * 0.18
                left_channel[sample_index] += mixed * left_gain
                right_channel[sample_index] += mixed * right_gain
            continue

        samples, loop_sample, source_rate, source_time, is_looped = waveform_payload
        if not samples:
            continue

        source_position = 0.0
        channel_started = False
        envelope_state = "start"
        amplitude = -ADSR_THRESHOLD
        modulation_delay_count = 0
        modulation_counter = 0
        modulation_units = 0
        dynamic_tick = note.start_tick
        dynamic_state = track_dynamic_states[min(dynamic_tick, len(track_dynamic_states) - 1)]
        next_control_time = start_time + SEQUENCE_TIMER_SECONDS
        for sample_index in range(start_sample, render_end_sample):
            sample_time = sample_index / output_rate
            if sample_time >= end_time + release_seconds:
                break

            while sample_time >= next_control_time:
                dynamic_tick, dynamic_state = dynamic_state_at_time(
                    track_dynamic_states,
                    dynamic_tick,
                    tick_times,
                    next_control_time,
                )
                if modulation_delay_count < dynamic_state.vibrato_delay:
                    modulation_delay_count += 1
                    modulation_units = 0
                elif dynamic_state.vibrato_depth > 0 and dynamic_state.vibrato_speed > 0 and dynamic_state.vibrato_range > 0:
                    speed = dynamic_state.vibrato_speed << 6
                    counter = (modulation_counter + speed) >> 8
                    while counter >= 0x80:
                        counter -= 0x80
                    modulation_counter += speed
                    modulation_counter &= 0xFF
                    modulation_counter |= counter << 8
                    modulation_units = (get_sound_sine(modulation_counter >> 8) * dynamic_state.vibrato_range * dynamic_state.vibrato_depth) >> 8
                else:
                    modulation_units = 0
                if sample_time >= end_time and envelope_state not in ("release", "done"):
                    envelope_state = "release"
                if envelope_state == "start":
                    amplitude = -ADSR_THRESHOLD
                    envelope_state = "attack"
                    channel_started = True
                if envelope_state == "attack":
                    amplitude = (attack_rate * amplitude) // 255
                    if amplitude == 0:
                        envelope_state = "decay"
                elif envelope_state == "decay":
                    amplitude -= decay_rate
                    if amplitude <= sustain_level:
                        amplitude = sustain_level
                        envelope_state = "sustain"
                elif envelope_state == "release":
                    amplitude -= release_rate
                    if amplitude <= -ADSR_THRESHOLD:
                        envelope_state = "done"
                next_control_time += SEQUENCE_TIMER_SECONDS

            if not channel_started or envelope_state == "done":
                continue

            pitch_units = pitch_units_for(note.pitch, note.note_definition.pitch, dynamic_state.pitch_bend, dynamic_state.pitch_bend_range)
            if dynamic_state.vibrato_type in (None, pitch_vibrato_type):
                pitch_units += modulation_units
            timer_value = adjust_freq(source_time, pitch_units)
            source_frequency = ARM7_CLOCK / max(1, timer_value)
            step = source_frequency / output_rate
            if source_position >= len(samples):
                break
            sample_floor = int(source_position)
            sample_ceil = min(sample_floor + 1, len(samples) - 1)
            sample_fraction = source_position - sample_floor
            sample_value = ((1.0 - sample_fraction) * samples[sample_floor]) + (sample_fraction * samples[sample_ceil])

            volume_modulation = modulation_units if dynamic_state.vibrato_type == 1 else 0
            pan_value = clamp_int(dynamic_state.pan + note.note_definition.pan - 64 + (modulation_units if dynamic_state.vibrato_type == 2 else 0), 0, 127)
            left_gain = 1.0 - (pan_value / 127.0)
            right_gain = pan_value / 127.0
            mixed = sample_value * volume_gain(
                matched_sequence.volume,
                dynamic_state.track_volume,
                dynamic_state.expression,
                note.velocity,
                amplitude,
                volume_modulation,
            ) * 0.72
            left_channel[sample_index] += mixed * left_gain
            right_channel[sample_index] += mixed * right_gain

            source_position += step
            if source_position >= len(samples):
                if is_looped:
                    source_position = float(loop_sample)
                    if loop_sample >= len(samples):
                        break
                else:
                    break

    output_wav.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output_wav), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(output_rate)
        frames = bytearray()
        for left_sample, right_sample in zip(left_channel, right_channel):
            left_value = clamp_int(int(clamp(left_sample, -1.0, 1.0) * 32767.0), -32768, 32767)
            right_value = clamp_int(int(clamp(right_sample, -1.0, 1.0) * 32767.0), -32768, 32767)
            frames.extend(struct.pack("<hh", left_value, right_value))
        handle.writeframes(frames)

    if output_json is not None:
        event_types = sorted({type(event).__name__ for event in events})
        used_instrument_ids = sorted({note.instrument_id for note in audible_notes})
        used_wave_archives = sorted(
            {
                bank.waveArchiveIDs[note.note_definition.waveArchiveIDID]
                for note in audible_notes
                if note.note_definition.type == ndspy.soundBank.NoteType.PCM
            }
        )
        track_timelines_json = [
            {
                "trackNumber": track_number,
                "states": [
                    {
                        "tick": state.tick,
                        "trackVolume": state.track_volume,
                        "expression": state.expression,
                        "pan": state.pan,
                        "trackPriority": state.track_priority,
                        "pitchBend": state.pitch_bend,
                        "pitchBendRange": state.pitch_bend_range,
                        "vibratoDepth": state.vibrato_depth,
                        "vibratoSpeed": state.vibrato_speed,
                        "vibratoRange": state.vibrato_range,
                        "vibratoDelay": state.vibrato_delay,
                        "vibratoType": state.vibrato_type,
                    }
                    for state in timeline
                ],
            }
            for track_number, timeline in sorted(track_dynamic_timelines.items())
        ]
        rendered_notes_json = []
        for note_index, (note, waveform_kind, waveform_payload, release_seconds) in enumerate(rendered_note_metadata):
            channel_allocation = note_channel_allocations[note_index]
            waveform_details = waveform_trace_details(note.note_definition, bank)
            if waveform_kind == "pcm":
                _, _, _, _, is_looped = waveform_payload
                waveform_details["isLooped"] = is_looped
            rendered_notes_json.append(
                {
                    "trackNumber": note.track_number,
                    "instrumentID": note.instrument_id,
                    "pitch": note.pitch,
                    "velocity": note.velocity,
                    "trackPriority": note.track_priority,
                    "startTick": note.start_tick,
                    "endTick": note.end_tick,
                    "startSeconds": tick_times[note.start_tick],
                    "endSeconds": tick_times[note.end_tick],
                    "releaseSeconds": release_seconds,
                    "allocatedChannel": channel_allocation.channel,
                    "droppedByChannelLimit": channel_allocation.dropped_by_channel_limit,
                    "allocationStartSample": channel_allocation.start_sample,
                    "allocationEndSample": channel_allocation.end_sample,
                    "noteType": note_type_name(note.note_definition),
                    "rootPitch": note.note_definition.pitch,
                    "notePan": note.note_definition.pan,
                    "attack": note.attack_rate if note.attack_rate is not None else note.note_definition.attack,
                    "decay": note.decay_rate if note.decay_rate is not None else note.note_definition.decay,
                    "sustain": note.sustain_rate if note.sustain_rate is not None else note.note_definition.sustain,
                    "release": note.release_rate if note.release_rate is not None else note.note_definition.release,
                    "waveformKind": waveform_kind,
                    **waveform_details,
                }
            )
        output_json.parent.mkdir(parents=True, exist_ok=True)
        with output_json.open("w", encoding="utf-8") as handle:
            json.dump(
                {
                    "bankID": matched_sequence.bankID,
                    "cueName": args.cue_name,
                    "durationSeconds": max_end_time,
                    "eventTypes": event_types,
                    "normalizationApplied": False,
                    "outputSampleRate": output_rate,
                    "playerChannels": allocatable_channels,
                    "playerID": matched_sequence.playerID,
                    "renderedNotes": rendered_notes_json,
                    "sequenceIndex": matched_index,
                    "tickCount": current_tick,
                    "trackCount": len(track_states),
                    "trackTimelines": track_timelines_json,
                    "targetDurationSeconds": args.target_duration_seconds,
                    "usedInstrumentIDs": used_instrument_ids,
                    "usedWaveArchives": used_wave_archives,
                },
                handle,
                indent=2,
                sort_keys=True,
            )


def fx32_to_float(value: int) -> float:
    if value & 0x80000000:
        value -= 0x100000000
    return value / 4096.0


def fx16_to_float(value: int) -> float:
    if value & 0x8000:
        value -= 0x10000
    return value / 4096.0


def rgb15_to_hex(value: int) -> str:
    red = int(round(((value & 0x1F) / 31.0) * 255.0))
    green = int(round((((value >> 5) & 0x1F) / 31.0) * 255.0))
    blue = int(round((((value >> 10) & 0x1F) / 31.0) * 255.0))
    return f"#{red:02X}{green:02X}{blue:02X}"


def render_tilemap(ncgr: NCGR, nscr: NSCR, nclr: NCLR) -> Image.Image:
    image = Image.new("RGBA", (nscr.width, nscr.height), (0, 0, 0, 0))

    for tile_y in range(nscr.height // 8):
        for tile_x in range(nscr.width // 8):
            entry = nscr.get_entry(tile_x, tile_y)
            if entry.tile >= len(ncgr.tiles):
                continue

            tile = flip_tile(ncgr.tiles[entry.tile], entry.xflip, entry.yflip)
            for pixel_y in range(8):
                for pixel_x in range(8):
                    color_index = tile[(pixel_y * 8) + pixel_x]

                    if ncgr.bpp == 4:
                        palette_index = (entry.pal * 16) + color_index
                    else:
                        palette_index = color_index

                    if palette_index >= len(nclr.colors):
                        continue

                    red, green, blue = nclr.colors[palette_index]
                    image.putpixel(
                        (tile_x * 8 + pixel_x, tile_y * 8 + pixel_y),
                        (red, green, blue, 255),
                    )

    return image


def decode_tilemap(args: argparse.Namespace) -> None:
    ncgr = NCGR.load_from(args.ncgr)
    nscr = NSCR.load_from(args.nscr)
    nclr = NCLR.load_from(args.nclr)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    render_tilemap(ncgr, nscr, nclr).save(output, "PNG")


def render_png_tilemap(
    sheet: Image.Image,
    nscr: NSCR,
    transparent_color: Optional[Tuple[int, int, int, int]] = None,
    crop_height: Optional[int] = None,
) -> Image.Image:
    tiles_per_row = sheet.width // 8
    total_tiles = tiles_per_row * (sheet.height // 8)
    image = Image.new("RGBA", (nscr.width, nscr.height), (0, 0, 0, 0))

    for tile_y in range(nscr.height // 8):
        for tile_x in range(nscr.width // 8):
            entry = nscr.get_entry(tile_x, tile_y)
            if entry.tile >= total_tiles:
                continue

            source_x = (entry.tile % tiles_per_row) * 8
            source_y = (entry.tile // tiles_per_row) * 8
            tile = sheet.crop((source_x, source_y, source_x + 8, source_y + 8))

            if entry.xflip:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            if entry.yflip:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)

            if transparent_color is not None:
                tile = tile.copy()
                pixels = [
                    (red, green, blue, 0) if pixel == transparent_color else pixel
                    for pixel in tile.getdata()
                    for red, green, blue, _ in [pixel]
                ]
                tile.putdata(pixels)

            image.alpha_composite(tile, (tile_x * 8, tile_y * 8))

    if crop_height is None or crop_height >= image.height:
        return image
    return image.crop((0, 0, image.width, crop_height))


def decode_png_tilemap(args: argparse.Namespace) -> None:
    sheet = Image.open(args.sheet).convert("RGBA")
    nscr = NSCR.load_from(args.nscr)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    transparent_color = sheet.getpixel((0, 0)) if args.transparent_top_left else None
    crop_height = args.crop_height if args.crop_height and args.crop_height > 0 else None
    render_png_tilemap(sheet, nscr, transparent_color=transparent_color, crop_height=crop_height).save(output, "PNG")


def signed_x(value: int) -> int:
    return value - 512 if value >= 256 else value


def signed_y(value: int) -> int:
    return value - 256 if value >= 128 else value


def cell_bounds(cell) -> Tuple[int, int, int, int]:
    if cell.oam:
        min_x = min(signed_x(oam.x) for oam in cell.oam)
        min_y = min(signed_y(oam.y) for oam in cell.oam)
        max_x = max(signed_x(oam.x) + oam.get_size()[0] for oam in cell.oam)
        max_y = max(signed_y(oam.y) + oam.get_size()[1] for oam in cell.oam)
    else:
        min_x = 0
        min_y = 0
        max_x = 8
        max_y = 8
    return min_x, min_y, max_x, max_y


def render_cell(
    cell,
    ncgr: NCGR,
    nclr: NCLR,
    *,
    canvas_min_x: Optional[int] = None,
    canvas_min_y: Optional[int] = None,
    canvas_width: Optional[int] = None,
    canvas_height: Optional[int] = None,
) -> Image.Image:
    min_x, min_y, max_x, max_y = cell_bounds(cell)
    if canvas_min_x is None:
        canvas_min_x = min_x
    if canvas_min_y is None:
        canvas_min_y = min_y
    if canvas_width is None:
        canvas_width = max(1, max_x - min_x)
    if canvas_height is None:
        canvas_height = max(1, max_y - min_y)

    image = Image.new("RGBA", (canvas_width, canvas_height), (0, 0, 0, 0))

    for oam in cell.oam:
        origin_x = signed_x(oam.x) - canvas_min_x
        origin_y = signed_y(oam.y) - canvas_min_y
        tile_width, tile_height = oam.get_size()
        tiles_x = tile_width // 8
        tiles_y = tile_height // 8
        hflip = (not oam.rot) and bool(oam.rotsca & 0x8)
        vflip = (not oam.rot) and bool(oam.rotsca & 0x10)

        for tile_y in range(tiles_y):
            for tile_x in range(tiles_x):
                tile_index = oam.char + (tile_y * tiles_x) + tile_x
                if tile_index >= len(ncgr.tiles):
                    continue

                tile = flip_tile(ncgr.tiles[tile_index], hflip, vflip)
                draw_tile_x = (tiles_x - 1 - tile_x) if hflip else tile_x
                draw_tile_y = (tiles_y - 1 - tile_y) if vflip else tile_y
                for pixel_y in range(8):
                    for pixel_x in range(8):
                        color_index = tile[(pixel_y * 8) + pixel_x]
                        if color_index == 0:
                            continue

                        if ncgr.bpp == 4:
                            palette_index = (oam.pal * 16) + color_index
                        else:
                            palette_index = color_index

                        if palette_index >= len(nclr.colors):
                            continue

                        red, green, blue = nclr.colors[palette_index]
                        image.putpixel(
                            (
                                origin_x + (draw_tile_x * 8) + pixel_x,
                                origin_y + (draw_tile_y * 8) + pixel_y,
                            ),
                            (red, green, blue, 255),
                        )

    return image


def decode_sprite(args: argparse.Namespace) -> None:
    ncgr = NCGR.load_from(args.ncgr)
    nclr = NCLR.load_from(args.nclr)
    ncer = NCER.load_from(args.ncer)
    nanr = NANR.load_from(args.nanr)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = {"sequences": []}

    for sequence_index, sequence in enumerate(nanr.anims):
        sequence_dir = output_dir / f"sequence_{sequence_index}"
        sequence_dir.mkdir(parents=True, exist_ok=True)

        valid_cells = [ncer.cells[frame.index] for frame in sequence.frames if frame.index < len(ncer.cells)]
        if valid_cells:
            bounds = [cell_bounds(cell) for cell in valid_cells]
            min_x = min(bound[0] for bound in bounds)
            min_y = min(bound[1] for bound in bounds)
            max_x = max(bound[2] for bound in bounds)
            max_y = max(bound[3] for bound in bounds)
        else:
            min_x = 0
            min_y = 0
            max_x = 8
            max_y = 8

        canvas_width = max(1, max_x - min_x)
        canvas_height = max(1, max_y - min_y)

        frames = []
        expanded_frames = []

        for frame_index, frame in enumerate(sequence.frames):
            cell_index = frame.index
            if cell_index >= len(ncer.cells):
                continue

            image = render_cell(
                ncer.cells[cell_index],
                ncgr,
                nclr,
                canvas_min_x=min_x,
                canvas_min_y=min_y,
                canvas_width=canvas_width,
                canvas_height=canvas_height,
            )
            filename = f"frame_{frame_index:03d}.png"
            relative_path = f"sequence_{sequence_index}/{filename}"
            image.save(sequence_dir / filename, "PNG")

            duration = getattr(frame, "duration", 1) or 1
            frame_min_x, frame_min_y, frame_max_x, frame_max_y = cell_bounds(ncer.cells[cell_index])
            frames.append(
                {
                    "canvasHeight": canvas_height,
                    "canvasWidth": canvas_width,
                    "cellIndex": cell_index,
                    "duration": duration,
                    "frameHeight": max(1, frame_max_y - frame_min_y),
                    "frameWidth": max(1, frame_max_x - frame_min_x),
                    "originX": frame_min_x,
                    "originY": frame_min_y,
                    "path": relative_path,
                }
            )
            expanded_frames.extend([relative_path] * duration)

        manifest["sequences"].append(
            {
                "canvasHeight": canvas_height,
                "canvasWidth": canvas_width,
                "expandedFrames": expanded_frames,
                "frames": frames,
                "index": sequence_index,
                "originX": min_x,
                "originY": min_y,
            }
        )
    manifest_path = output_dir / "manifest.json"
    with manifest_path.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)


def extract_narc_members(args: argparse.Namespace) -> None:
    narc = ndspy.narc.NARC.fromFile(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for member in args.members:
        member_index = int(member)
        if member_index < 0 or member_index >= len(narc.files):
            raise ValueError(f"NARC member index {member_index} is out of range for {args.input}")

        payload = narc.files[member_index]
        if args.auto_decompress_lz10 and payload[:1] == b"\x10":
            payload = ndspy.lz10.decompress(payload)

        (output_dir / f"{member_index}.bin").write_bytes(payload)


def render_ncgr_sheet(args: argparse.Namespace) -> None:
    ncgr = NCGR.load_from(args.ncgr)
    nclr = NCLR.load_from(args.nclr)
    width_tiles = max(1, int(args.width_tiles))
    tile_count = len(ncgr.tiles)
    height_tiles = max(1, math.ceil(tile_count / width_tiles))
    image = Image.new("RGBA", (width_tiles * 8, height_tiles * 8), (0, 0, 0, 0))

    for tile_index, tile in enumerate(ncgr.tiles):
        tile_x = tile_index % width_tiles
        tile_y = tile_index // width_tiles
        for pixel_index, color_index in enumerate(tile):
            pixel_x = pixel_index % 8
            pixel_y = pixel_index // 8
            if color_index >= len(nclr.colors):
                continue
            red, green, blue = nclr.colors[color_index]
            alpha = 0 if args.transparent_index_zero and color_index == 0 else 255
            image.putpixel(
                (tile_x * 8 + pixel_x, tile_y * 8 + pixel_y),
                (red, green, blue, alpha),
            )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, "PNG")


def summarize_sdat(args: argparse.Namespace) -> None:
    archive_path = Path(args.input)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    archive = ndspy.soundArchive.SDAT(archive_path.read_bytes())
    summary = {
        "sequences": [
            {
                "bankID": None if sequence is None else sequence.bankID,
                "index": index,
                "name": name,
            }
            for index, (name, sequence) in enumerate(archive.sequences)
        ],
        "waveArchives": [
            {
                "index": index,
                "name": name,
            }
            for index, (name, _) in enumerate(archive.waveArchives)
        ],
    }

    with output.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)


def extract_scene4_particles(args: argparse.Namespace) -> None:
    output_dir = Path(args.output_dir)
    textures_dir = output_dir / "textures"
    output_dir.mkdir(parents=True, exist_ok=True)
    textures_dir.mkdir(parents=True, exist_ok=True)

    particle_narc = ndspy.narc.NARC.fromFile(args.narc)
    if args.member < 0 or args.member >= len(particle_narc.files):
        raise ValueError(f"Invalid NARC member {args.member}; archive has {len(particle_narc.files)} files.")
    blob = particle_narc.files[args.member]

    if blob[:8] != b" APS12_1":
        raise ValueError(f"Unexpected APS header in member {args.member}: {blob[:8]!r}")

    resource_count, texture_count = struct.unpack_from("<HH", blob, 0x08)
    offset = 0x20
    resources = []

    for resource_id in range(resource_count):
        flag = struct.unpack_from("<I", blob, offset)[0]
        pos_x, pos_y, pos_z = struct.unpack_from("<iii", blob, offset + 0x04)
        gen_num, radius, length = struct.unpack_from("<iii", blob, offset + 0x10)
        axis_x, axis_y, axis_z = struct.unpack_from("<HHH", blob, offset + 0x1C)
        color = struct.unpack_from("<H", blob, offset + 0x22)[0]
        init_vel_mag_pos, init_vel_mag_axis, base_scl = struct.unpack_from("<iii", blob, offset + 0x24)
        aspect = struct.unpack_from("<H", blob, offset + 0x30)[0]
        start_offset = struct.unpack_from("<H", blob, offset + 0x32)[0]
        rtt_min, rtt_max = struct.unpack_from("<hh", blob, offset + 0x34)
        init_rtt = struct.unpack_from("<H", blob, offset + 0x38)[0]
        emtr_life, ptcl_life = struct.unpack_from("<HH", blob, offset + 0x3C)
        rndm = struct.unpack_from("<I", blob, offset + 0x40)[0]
        etc0, etc1, etc2 = struct.unpack_from("<III", blob, offset + 0x44)
        offset_x, offset_y = struct.unpack_from("<hh", blob, offset + 0x50)
        usr_flag = struct.unpack_from("<I", blob, offset + 0x54)[0] & 0xFF

        cursor = offset + 0x58
        resource = {
            "id": resource_id,
            "offset": offset,
            "base": {
                "position": {
                    "x": fx32_to_float(pos_x),
                    "y": fx32_to_float(pos_y),
                    "z": fx32_to_float(pos_z),
                },
                "generationRate": fx32_to_float(gen_num),
                "radius": fx32_to_float(radius),
                "length": fx32_to_float(length),
                "axis": {
                    "x": fx16_to_float(axis_x),
                    "y": fx16_to_float(axis_y),
                    "z": fx16_to_float(axis_z),
                },
                "colorHex": rgb15_to_hex(color),
                "initVelocityMagnitudePosition": fx32_to_float(init_vel_mag_pos),
                "initVelocityMagnitudeAxis": fx32_to_float(init_vel_mag_axis),
                "baseScale": fx32_to_float(base_scl),
                "aspect": fx16_to_float(aspect),
                "startOffsetFrames": start_offset,
                "rotationVelocityRange": {
                    "min": rtt_min,
                    "max": rtt_max,
                },
                "initialRotation": init_rtt,
                "emitterLifeFrames": emtr_life,
                "particleLifeFrames": ptcl_life,
                "randomization": {
                    "baseScale": rndm & 0xFF,
                    "particleLife": (rndm >> 8) & 0xFF,
                    "initialVelocityMagnitude": (rndm >> 16) & 0xFF,
                },
                "etc": {
                    "generationIntervalFrames": etc0 & 0xFF,
                    "baseAlpha": (etc0 >> 8) & 0xFF,
                    "airResistance": (etc0 >> 16) & 0xFF,
                    "textureIndex": (etc0 >> 24) & 0xFF,
                    "loopFrame": etc1 & 0xFF,
                    "billboardScale": (etc1 >> 8) & 0xFFFF,
                    "textureRepeatS": etc2 & 0x3,
                    "textureRepeatT": (etc2 >> 2) & 0x3,
                    "scaleAnimationDirection": (etc2 >> 4) & 0x7,
                    "centerOnPolygon": bool((etc2 >> 7) & 0x1),
                    "reverseTextureS": bool((etc2 >> 8) & 0x1),
                    "reverseTextureT": bool((etc2 >> 9) & 0x1),
                    "offsetPositionMode": (etc2 >> 10) & 0x7,
                },
                "offset": {
                    "x": fx16_to_float(offset_x & 0xFFFF),
                    "y": fx16_to_float(offset_y & 0xFFFF),
                    "rawX": offset_x,
                    "rawY": offset_y,
                },
                "userFlag": usr_flag,
            },
            "flags": {
                "raw": flag,
                "initPositionType": flag & 0xF,
                "drawType": (flag >> 4) & 0x3,
                "circleAxis": (flag >> 6) & 0x3,
                "usesScaleAnimation": bool((flag >> 8) & 0x1),
                "usesColorAnimation": bool((flag >> 9) & 0x1),
                "usesAlphaAnimation": bool((flag >> 10) & 0x1),
                "usesTextureAnimation": bool((flag >> 11) & 0x1),
                "usesRotationAnimation": bool((flag >> 12) & 0x1),
                "usesRandomInitialRotation": bool((flag >> 13) & 0x1),
                "selfDestructs": bool((flag >> 14) & 0x1),
                "followsEmitter": bool((flag >> 15) & 0x1),
                "usesChild": bool((flag >> 16) & 0x1),
                "polygonRotationAxis": (flag >> 17) & 0x3,
                "polygonBasePlane": bool((flag >> 19) & 0x1),
                "usesRandomLoopAnimation": bool((flag >> 20) & 0x1),
                "drawChildFirst": bool((flag >> 21) & 0x1),
                "drawParent": bool((flag >> 22) & 0x1),
                "cameraOffset": bool((flag >> 23) & 0x1),
                "usesGravityField": bool((flag >> 24) & 0x1),
                "usesRandomField": bool((flag >> 25) & 0x1),
                "usesMagnetField": bool((flag >> 26) & 0x1),
                "usesSpinField": bool((flag >> 27) & 0x1),
                "usesScField": bool((flag >> 28) & 0x1),
                "usesConvergenceField": bool((flag >> 29) & 0x1),
                "polygonIDFixed": bool((flag >> 30) & 0x1),
                "childPolygonIDFixed": bool((flag >> 31) & 0x1),
            },
        }

        if flag & (1 << 8):
            scl_s, scl_n, scl_e, in_out, etc = struct.unpack_from("<HHHHH", blob, cursor)
            resource["scaleAnimation"] = {
                "start": fx16_to_float(scl_s),
                "mid": fx16_to_float(scl_n),
                "end": fx16_to_float(scl_e),
                "inFrames": in_out & 0xFF,
                "outFrames": (in_out >> 8) & 0xFF,
                "loops": bool(etc & 0x1),
            }
            cursor += 0x0C

        if flag & (1 << 9):
            clr_s, clr_e, in_peak_out, etc, _ = struct.unpack_from("<HHIHH", blob, cursor)
            resource["colorAnimation"] = {
                "startHex": rgb15_to_hex(clr_s),
                "endHex": rgb15_to_hex(clr_e),
                "inFrames": in_peak_out & 0xFF,
                "peakFrames": (in_peak_out >> 8) & 0xFF,
                "outFrames": (in_peak_out >> 16) & 0xFF,
                "usesRandom": bool(etc & 0x1),
                "loops": bool((etc >> 1) & 0x1),
                "interpolates": bool((etc >> 2) & 0x1),
            }
            cursor += 0x0C

        if flag & (1 << 10):
            alpha_values, etc, in_out, _ = struct.unpack_from("<HHHH", blob, cursor)
            resource["alphaAnimation"] = {
                "start": alpha_values & 0x1F,
                "mid": (alpha_values >> 5) & 0x1F,
                "end": (alpha_values >> 10) & 0x1F,
                "flicker": etc & 0xFF,
                "loops": bool((etc >> 8) & 0x1),
                "inFrames": in_out & 0xFF,
                "outFrames": (in_out >> 8) & 0xFF,
            }
            cursor += 0x08

        if flag & (1 << 11):
            tex_no = list(blob[cursor:cursor + 8])
            etc = struct.unpack_from("<I", blob, cursor + 8)[0]
            resource["textureAnimation"] = {
                "textureIndices": tex_no,
                "useCount": etc & 0xFF,
                "frameStep": (etc >> 8) & 0xFF,
                "usesRandom": bool((etc >> 16) & 0x1),
                "loops": bool((etc >> 17) & 0x1),
            }
            cursor += 0x0C

        if flag & (1 << 16):
            child_flag, init_vel_mag_rndm, scl_e, life, ratio, child_color, child_etc0, child_etc1 = struct.unpack_from("<HHHHHHII", blob, cursor)
            resource["child"] = {
                "flagRaw": child_flag,
                "flags": {
                    "affectsFields": bool(child_flag & 0x1),
                    "usesScaleAnimation": bool((child_flag >> 1) & 0x1),
                    "usesAlphaAnimation": bool((child_flag >> 2) & 0x1),
                    "rotationType": (child_flag >> 3) & 0x3,
                    "followsEmitter": bool((child_flag >> 5) & 0x1),
                    "usesChildColor": bool((child_flag >> 6) & 0x1),
                    "drawType": (child_flag >> 7) & 0x3,
                    "polygonRotationAxis": (child_flag >> 9) & 0x3,
                    "polygonBasePlane": bool((child_flag >> 11) & 0x1),
                },
                "initialVelocityMagnitudeRandom": fx16_to_float(init_vel_mag_rndm),
                "endScale": fx16_to_float(scl_e),
                "lifeFrames": life,
                "velocityRatio": ratio & 0xFF,
                "scaleRatio": (ratio >> 8) & 0xFF,
                "colorHex": rgb15_to_hex(child_color),
                "generationCount": child_etc0 & 0xFF,
                "generationStartFrame": (child_etc0 >> 8) & 0xFF,
                "generationIntervalFrames": (child_etc0 >> 16) & 0xFF,
                "textureIndex": (child_etc0 >> 24) & 0xFF,
                "textureRepeatS": child_etc1 & 0x3,
                "textureRepeatT": (child_etc1 >> 2) & 0x3,
                "reverseTextureS": bool((child_etc1 >> 4) & 0x1),
                "reverseTextureT": bool((child_etc1 >> 5) & 0x1),
                "centerOnPolygon": bool((child_etc1 >> 6) & 0x1),
            }
            cursor += 0x14

        field_blocks = []
        field_layout = [
            (24, 0x08, "gravity"),
            (25, 0x08, "random"),
            (26, 0x10, "magnet"),
            (27, 0x04, "spin"),
            (28, 0x08, "scfield"),
            (29, 0x10, "convergence"),
        ]
        for bit, size, name in field_layout:
            if flag & (1 << bit):
                raw = blob[cursor:cursor + size]
                field_block = {
                    "kind": name,
                    "offset": cursor,
                    "rawHex": raw.hex(),
                }
                if name == "spin":
                    step_raw, axis = struct.unpack_from("<HH", raw, 0)
                    field_block["rotationStepRaw"] = step_raw
                    field_block["rotationStepIndex"] = step_raw >> 4
                    field_block["axis"] = axis
                elif name == "magnet":
                    field_block["position"] = {
                        "x": fx32_to_float(struct.unpack_from("<i", raw, 0)[0]),
                        "y": fx32_to_float(struct.unpack_from("<i", raw, 4)[0]),
                        "z": fx32_to_float(struct.unpack_from("<i", raw, 8)[0]),
                    }
                    field_block["strengthRaw"] = struct.unpack_from("<I", raw, 12)[0]
                field_blocks.append(
                    field_block
                )
                cursor += size
        resource["fieldBlocks"] = field_blocks
        resources.append(resource)
        offset = cursor

    textures = []
    for texture_id in range(texture_count):
        if blob[offset:offset + 4] != b" TPS":
            raise ValueError(f"Unexpected texture header at {offset:#x}: {blob[offset:offset + 4]!r}")
        flags, tex_size, pltt_ofs, pltt_size = struct.unpack_from("<IIII", blob, offset + 0x04)
        total_size = struct.unpack_from("<I", blob, offset + 0x1C)[0]
        tex_format = ndspy.texture.TextureFormat(flags & 0xF)
        width = 1 << (((flags >> 4) & 0xF) + 3)
        height = 1 << (((flags >> 8) & 0xF) + 3)
        texture_data = blob[offset + 0x20:offset + 0x20 + tex_size]
        palette_data = blob[offset + pltt_ofs:offset + pltt_ofs + pltt_size]
        palette = [
            struct.unpack_from("<H", palette_data, palette_offset)[0]
            for palette_offset in range(0, len(palette_data), 2)
        ]
        image = ndspy.texture.renderTextureDataAsImage(
            texture_data,
            None,
            tex_format,
            width,
            height,
            palette=palette,
            isColor0Transparent=True,
        )
        texture_name = f"texture_{texture_id:02d}.png"
        texture_path = textures_dir / texture_name
        image.save(texture_path, "PNG")
        textures.append(
            {
                "id": texture_id,
                "offset": offset,
                "format": tex_format.name,
                "width": width,
                "height": height,
                "flagsRaw": flags,
                "textureSizeBytes": tex_size,
                "paletteOffset": pltt_ofs,
                "paletteSizeBytes": pltt_size,
                "totalBlockSizeBytes": total_size,
                "path": f"textures/{texture_name}",
            }
        )
        offset += total_size

    summary = {
        "archivePath": str(Path(args.narc)),
        "memberIndex": args.member,
        "resources": resources,
        "textures": textures,
    }
    output = output_dir / "scene4_particles.json"
    with output.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)


SCENE4_PARTICLE_SURFACE_SIZE = (256, 192)
SCENE4_PIXELS_PER_WORLD_UNIT = 32.0
SCENE4_PHASE_RESOURCE_IDS = {
    "grass": (6, 7, 8),
    "fire": (3, 4, 5),
    "water": (0, 1, 2),
}
SCENE4_PHASE_BASE_DRIFT = {
    "grass": (0.0, -0.35),
    "fire": (0.0, -0.7),
    "water": (0.0, -0.45),
}
SCENE4_PHASE_VERTICAL_ACCELERATION = {
    "grass": 0.03,
    "fire": -0.02,
    "water": 0.18,
}


@dataclass
class Scene4ParticleInstance:
    resource_id: int
    texture_index: int
    position_x: float
    position_y: float
    velocity_x: float
    velocity_y: float
    life_frames: int
    age_frames: int = 0
    initial_rotation_degrees: float = 0.0
    rotation_velocity_degrees: float = 0.0
    child_spawned: bool = False
    can_emit_children: bool = True


class Scene4ParticleRNG:
    def __init__(self, seed: int) -> None:
        self.seed = seed & 0xFFFFFFFF

    def next_u32(self) -> int:
        self.seed = (self.seed * 0x5EEDF715 + 0x1B0CB173) & 0xFFFFFFFF
        return self.seed

    def next_float(self) -> float:
        return self.next_u32() / 0x100000000

    def next_signed_shift8(self) -> int:
        value = self.next_u32()
        if value & 0x80000000:
            value -= 0x100000000
        return value >> 8

    def unit_xy(self) -> Tuple[float, float]:
        x = float(self.next_signed_shift8())
        y = float(self.next_signed_shift8())
        return normalize_vector2(x, y)


def lerp_float(start: float, end: float, progress: float) -> float:
    progress = clamp(progress, 0.0, 1.0)
    return start + ((end - start) * progress)


def normalize_vector2(x: float, y: float) -> Tuple[float, float]:
    magnitude = math.hypot(x, y)
    if magnitude <= 1e-8:
        return (1.0, 0.0)
    return (x / magnitude, y / magnitude)


def hex_to_rgb(hex_value: str) -> Tuple[int, int, int]:
    value = hex_value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def tinted_image(image: Image.Image, tint: Tuple[int, int, int], opacity: float) -> Image.Image:
    output = image
    if tint != (255, 255, 255):
        tint_layer = Image.new("RGBA", image.size, tint + (255,))
        output = ImageChops.multiply(output, tint_layer)
    if opacity < 1.0:
        alpha = output.getchannel("A").point(lambda value: int(value * clamp(opacity, 0.0, 1.0)))
        output.putalpha(alpha)
    return output


def animated_curve(start: float, mid: float, end: float, age_frames: int, life_frames: int, in_frames: int, out_frames: int) -> float:
    if life_frames <= 1:
        return end
    if in_frames > 0 and age_frames < in_frames:
        return lerp_float(start, mid, age_frames / max(1, in_frames - 1))
    out_start = max(in_frames, life_frames - out_frames)
    if out_frames > 0 and age_frames >= out_start:
        return lerp_float(mid, end, (age_frames - out_start) / max(1, out_frames - 1))
    return mid


def scene4_particle_life_frames(resource: Dict[str, object], rng: Scene4ParticleRNG) -> int:
    base_life = int(resource["base"]["particleLifeFrames"])
    random_span = int(resource["base"]["randomization"]["particleLife"])
    if random_span <= 0:
        return max(1, base_life)
    variation = int(round((rng.next_float() - 0.5) * random_span))
    return max(1, base_life + variation)


def scene4_phase_emitter_center() -> Tuple[float, float]:
    width, height = SCENE4_PARTICLE_SURFACE_SIZE
    return (width / 2.0, height / 2.0)


def scene4_effective_base_position(resource: Dict[str, object]) -> Tuple[float, float]:
    base_position = resource["base"]["position"]
    x = float(base_position["x"])
    y = float(base_position["y"])
    if abs(x) > 64.0:
        x = 0.0
    if abs(y) > 64.0:
        y = 0.0
    return (x * SCENE4_PIXELS_PER_WORLD_UNIT, -y * SCENE4_PIXELS_PER_WORLD_UNIT)


def scene4_spawn_offset(resource: Dict[str, object], rng: Scene4ParticleRNG) -> Tuple[float, float]:
    radius = float(resource["base"]["radius"])
    length = float(resource["base"]["length"])
    direction_x, direction_y = rng.unit_xy()
    init_position_type = int(resource["flags"]["initPositionType"])
    circle_axis = int(resource["flags"]["circleAxis"])

    local_x = 0.0
    local_y = 0.0
    local_z = 0.0

    if init_position_type == 0:
        local_x = 0.0
        local_y = 0.0
        local_z = 0.0
    elif init_position_type == 2:
        local_x = radius * direction_x
        local_y = radius * direction_y
    elif init_position_type == 6:
        local_x = radius * direction_x
        local_y = radius * direction_y
        local_z = length * ((((rng.next_u32() >> 23) & 0x1FF) - 256) / 256.0)
    elif init_position_type == 7:
        local_x = radius * direction_x * ((((rng.next_u32() >> 23) & 0x1FF) - 256) / 256.0)
        local_y = radius * direction_y * ((((rng.next_u32() >> 23) & 0x1FF) - 256) / 256.0)
        local_z = length * ((((rng.next_u32() >> 23) & 0x1FF) - 256) / 256.0)
    else:
        local_x = radius * direction_x
        local_y = radius * direction_y

    if circle_axis == 0:
        world_x, world_y = -local_x, -local_y
    elif circle_axis == 2:
        world_x, world_y = local_z, -local_y
    else:
        world_x, world_y = local_x, local_y

    return (
        world_x * SCENE4_PIXELS_PER_WORLD_UNIT,
        -world_y * SCENE4_PIXELS_PER_WORLD_UNIT,
    )


def scene4_spawn_velocity(resource: Dict[str, object], phase_id: str, offset_x: float, offset_y: float, rng: Scene4ParticleRNG) -> Tuple[float, float]:
    direction_x, direction_y = normalize_vector2(offset_x, offset_y)
    if abs(offset_x) <= 1e-6 and abs(offset_y) <= 1e-6:
        direction_x, direction_y = rng.unit_xy()

    magnitude_position = float(resource["base"]["initVelocityMagnitudePosition"]) * SCENE4_PIXELS_PER_WORLD_UNIT
    magnitude_axis = float(resource["base"]["initVelocityMagnitudeAxis"]) * SCENE4_PIXELS_PER_WORLD_UNIT
    drift_x, drift_y = SCENE4_PHASE_BASE_DRIFT[phase_id]
    velocity_x = (direction_x * magnitude_position) + drift_x
    velocity_y = (direction_y * magnitude_position) + drift_y - magnitude_axis
    return (velocity_x, velocity_y)


def scene4_rotation_velocity(resource: Dict[str, object]) -> float:
    for field_block in resource.get("fieldBlocks", []):
        if field_block.get("kind") == "spin":
            return float(field_block.get("rotationStepRaw", 0)) / 128.0
    return 0.0


def scene4_particle_scale(resource: Dict[str, object], particle: Scene4ParticleInstance) -> float:
    base_scale = float(resource["base"]["baseScale"])
    scale_animation = resource.get("scaleAnimation")
    if not scale_animation:
        return max(0.01, base_scale)
    return max(
        0.01,
        animated_curve(
            float(scale_animation["start"]),
            float(scale_animation["mid"]),
            float(scale_animation["end"]),
            particle.age_frames,
            particle.life_frames,
            int(scale_animation["inFrames"]),
            int(scale_animation["outFrames"]),
        ),
    )


def scene4_particle_opacity(resource: Dict[str, object], particle: Scene4ParticleInstance) -> float:
    alpha_animation = resource.get("alphaAnimation")
    if not alpha_animation:
        return 1.0
    alpha_value = animated_curve(
        float(alpha_animation["start"]),
        float(alpha_animation["mid"]),
        float(alpha_animation["end"]),
        particle.age_frames,
        particle.life_frames,
        int(alpha_animation["inFrames"]),
        int(alpha_animation["outFrames"]),
    )
    return clamp(alpha_value / 31.0, 0.0, 1.0)


def scene4_particle_tint(resource: Dict[str, object], particle: Scene4ParticleInstance) -> Tuple[int, int, int]:
    color_animation = resource.get("colorAnimation")
    if not color_animation:
        return hex_to_rgb(resource["base"]["colorHex"])

    start = hex_to_rgb(color_animation["startHex"])
    end = hex_to_rgb(color_animation["endHex"])
    progress = particle.age_frames / max(1, particle.life_frames - 1)
    return (
        int(round(lerp_float(start[0], end[0], progress))),
        int(round(lerp_float(start[1], end[1], progress))),
        int(round(lerp_float(start[2], end[2], progress))),
    )


def scene4_prepare_particle_image(
    base_image: Image.Image,
    scale: float,
    aspect: float,
    rotation_degrees: float,
    tint: Tuple[int, int, int],
    opacity: float,
) -> Image.Image:
    width = max(1, int(round(base_image.width * scale)))
    height = max(1, int(round(base_image.height * scale * max(0.1, aspect))))
    output = base_image.resize((width, height), resample=PIL_NEAREST)
    output = tinted_image(output, tint, opacity)
    if abs(rotation_degrees) > 1e-6:
        output = output.rotate(-rotation_degrees, resample=PIL_NEAREST, expand=True)
    return output


def scene4_spawn_child_particles(
    resource: Dict[str, object],
    parent: Scene4ParticleInstance,
    child: Dict[str, object],
) -> List[Scene4ParticleInstance]:
    result: List[Scene4ParticleInstance] = []
    generation_count = max(1, int(child["generationCount"]))
    velocity_ratio = float(child["velocityRatio"]) / 100.0
    for _ in range(generation_count):
        result.append(
            Scene4ParticleInstance(
                resource_id=parent.resource_id,
                texture_index=int(child["textureIndex"]),
                position_x=parent.position_x,
                position_y=parent.position_y,
                velocity_x=parent.velocity_x * velocity_ratio,
                velocity_y=parent.velocity_y * velocity_ratio,
                life_frames=max(1, int(child["lifeFrames"])),
                initial_rotation_degrees=0.0,
                rotation_velocity_degrees=0.0,
                can_emit_children=False,
            )
        )
    return result


def scene4_render_particle(
    canvas: Image.Image,
    particle: Scene4ParticleInstance,
    resource: Dict[str, object],
    textures_by_id: Dict[int, Image.Image],
) -> None:
    texture = textures_by_id.get(particle.texture_index)
    if texture is None:
        return

    scale = scene4_particle_scale(resource, particle)
    tint = scene4_particle_tint(resource, particle)
    opacity = scene4_particle_opacity(resource, particle)
    aspect = float(resource["base"]["aspect"])
    rotation_degrees = particle.initial_rotation_degrees + (particle.rotation_velocity_degrees * particle.age_frames)
    rendered = scene4_prepare_particle_image(
        base_image=texture,
        scale=scale,
        aspect=aspect,
        rotation_degrees=rotation_degrees,
        tint=tint,
        opacity=opacity,
    )
    destination_x = int(round(particle.position_x - (rendered.width / 2.0)))
    destination_y = int(round(particle.position_y - (rendered.height / 2.0)))
    canvas.alpha_composite(rendered, (destination_x, destination_y))


def scene4_update_particle(
    particle: Scene4ParticleInstance,
    resource: Dict[str, object],
    phase_id: str,
    emitter_center: Tuple[float, float],
) -> None:
    air_resistance = float(resource["base"]["etc"]["airResistance"]) / 255.0
    particle.velocity_x *= max(0.0, 1.0 - (air_resistance * 0.1))
    particle.velocity_y *= max(0.0, 1.0 - (air_resistance * 0.1))
    particle.velocity_y += SCENE4_PHASE_VERTICAL_ACCELERATION[phase_id]

    for field_block in resource.get("fieldBlocks", []):
        if field_block.get("kind") != "magnet":
            continue
        target_x = emitter_center[0] + (float(field_block["position"]["x"]) * SCENE4_PIXELS_PER_WORLD_UNIT)
        target_y = emitter_center[1] - (float(field_block["position"]["y"]) * SCENE4_PIXELS_PER_WORLD_UNIT)
        direction_x, direction_y = normalize_vector2(target_x - particle.position_x, target_y - particle.position_y)
        strength = float(field_block.get("strengthRaw", 0)) / 256.0
        particle.velocity_x += direction_x * strength
        particle.velocity_y += direction_y * strength

    particle.position_x += particle.velocity_x
    particle.position_y += particle.velocity_y
    particle.age_frames += 1


def scene4_emit_particles_for_frame(
    resource: Dict[str, object],
    phase_id: str,
    frame_index: int,
    emitter_state: Dict[str, float],
    rng: Scene4ParticleRNG,
    emitter_center: Tuple[float, float],
) -> List[Scene4ParticleInstance]:
    start_offset = int(resource["base"]["startOffsetFrames"])
    emitter_life_frames = int(resource["base"]["emitterLifeFrames"])
    if frame_index < start_offset or frame_index >= start_offset + emitter_life_frames:
        return []

    generation_interval_frames = max(1, int(resource["base"]["etc"]["generationIntervalFrames"]))
    if (frame_index - start_offset) % generation_interval_frames != 0:
        return []

    emitter_state["accumulator"] += float(resource["base"]["generationRate"])
    emit_count = int(emitter_state["accumulator"])
    emitter_state["accumulator"] -= emit_count
    if emit_count == 0 and float(resource["base"]["generationRate"]) > 0.0:
        emit_count = 1

    base_offset_x, base_offset_y = scene4_effective_base_position(resource)
    particles: List[Scene4ParticleInstance] = []
    for _ in range(emit_count):
        offset_x, offset_y = scene4_spawn_offset(resource, rng)
        velocity_x, velocity_y = scene4_spawn_velocity(resource, phase_id, offset_x, offset_y, rng)
        initial_rotation = 0.0
        if resource["flags"].get("usesRandomInitialRotation"):
            initial_rotation = rng.next_float() * 360.0
        particles.append(
            Scene4ParticleInstance(
                resource_id=int(resource["id"]),
                texture_index=int(resource["base"]["etc"]["textureIndex"]),
                position_x=emitter_center[0] + base_offset_x + offset_x,
                position_y=emitter_center[1] + base_offset_y + offset_y,
                velocity_x=velocity_x,
                velocity_y=velocity_y,
                life_frames=scene4_particle_life_frames(resource, rng),
                initial_rotation_degrees=initial_rotation,
                rotation_velocity_degrees=scene4_rotation_velocity(resource),
            )
        )
    return particles


def bake_scene4_particles(args: argparse.Namespace) -> None:
    manifest_path = Path(args.manifest)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with manifest_path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)

    textures_by_id = {
        int(texture["id"]): Image.open(manifest_path.parent / texture["path"]).convert("RGBA")
        for texture in manifest["textures"]
    }
    resources_by_id = {
        int(resource["id"]): resource
        for resource in manifest["resources"]
    }

    emitter_center = scene4_phase_emitter_center()
    rng = Scene4ParticleRNG(seed=args.seed)
    baked_phases = []

    for phase_id, resource_ids in SCENE4_PHASE_RESOURCE_IDS.items():
        resources = [resources_by_id[resource_id] for resource_id in resource_ids]
        phase_duration_frames = max(
            int(resource["base"]["startOffsetFrames"])
            + int(resource["base"]["emitterLifeFrames"])
            + int(resource["base"]["particleLifeFrames"])
            + int(resource.get("child", {}).get("lifeFrames", 0))
            + 1
            for resource in resources
        )
        phase_output_dir = output_dir / phase_id
        phase_output_dir.mkdir(parents=True, exist_ok=True)

        emitter_states = {
            int(resource["id"]): {"accumulator": 0.0}
            for resource in resources
        }
        particles: List[Scene4ParticleInstance] = []
        frame_paths = []

        for frame_index in range(phase_duration_frames):
            for resource in resources:
                particles.extend(
                    scene4_emit_particles_for_frame(
                        resource=resource,
                        phase_id=phase_id,
                        frame_index=frame_index,
                        emitter_state=emitter_states[int(resource["id"])],
                        rng=rng,
                        emitter_center=emitter_center,
                    )
                )

            canvas = Image.new("RGBA", SCENE4_PARTICLE_SURFACE_SIZE, (0, 0, 0, 0))
            next_particles: List[Scene4ParticleInstance] = []
            spawned_children: List[Scene4ParticleInstance] = []

            for particle in particles:
                resource = resources_by_id[particle.resource_id]
                if particle.age_frames > particle.life_frames:
                    continue

                scene4_render_particle(
                    canvas=canvas,
                    particle=particle,
                    resource=resource,
                    textures_by_id=textures_by_id,
                )

                child = resource.get("child")
                if child and particle.can_emit_children:
                    generation_start_frame = int(math.ceil((particle.life_frames * int(child["generationStartFrame"])) / 256.0))
                    generation_interval_frames = max(1, int(child["generationIntervalFrames"]))
                    delta = particle.age_frames - generation_start_frame
                    if delta >= 0 and delta % generation_interval_frames == 0:
                        spawned_children.extend(scene4_spawn_child_particles(resource, particle, child))

                scene4_update_particle(
                    particle=particle,
                    resource=resource,
                    phase_id=phase_id,
                    emitter_center=emitter_center,
                )

                if particle.age_frames <= particle.life_frames:
                    next_particles.append(particle)

            particles = next_particles + spawned_children
            frame_name = f"frame_{frame_index:03d}.png"
            frame_path = phase_output_dir / frame_name
            canvas.save(frame_path, "PNG")
            frame_paths.append(f"{phase_id}/{frame_name}")

        baked_phases.append(
            {
                "id": phase_id,
                "resourceIDs": list(resource_ids),
                "durationFrames": phase_duration_frames,
                "framePaths": frame_paths,
            }
        )

    output_path = output_dir / "scene4_particle_frames.json"
    with output_path.open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "seed": args.seed,
                "surfaceHeight": SCENE4_PARTICLE_SURFACE_SIZE[1],
                "surfaceWidth": SCENE4_PARTICLE_SURFACE_SIZE[0],
                "phases": baked_phases,
            },
            handle,
            indent=2,
            sort_keys=True,
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Decode HeartGold opening assets.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    tilemap = subparsers.add_parser("tilemap", help="Decode an NCGR/NSCR/NCLR tilemap to PNG.")
    tilemap.add_argument("--ncgr", required=True)
    tilemap.add_argument("--nscr", required=True)
    tilemap.add_argument("--nclr", required=True)
    tilemap.add_argument("--output", required=True)
    tilemap.set_defaults(func=decode_tilemap)

    png_tilemap = subparsers.add_parser("png-tilemap", help="Compose a PNG tile sheet through an NSCR tilemap.")
    png_tilemap.add_argument("--sheet", required=True)
    png_tilemap.add_argument("--nscr", required=True)
    png_tilemap.add_argument("--output", required=True)
    png_tilemap.add_argument("--crop-height", type=int)
    png_tilemap.add_argument("--transparent-top-left", action="store_true")
    png_tilemap.set_defaults(func=decode_png_tilemap)

    sprite = subparsers.add_parser("sprite", help="Decode NCER/NANR sprite sequences to PNG frames.")
    sprite.add_argument("--ncgr", required=True)
    sprite.add_argument("--nclr", required=True)
    sprite.add_argument("--ncer", required=True)
    sprite.add_argument("--nanr", required=True)
    sprite.add_argument("--output-dir", required=True)
    sprite.set_defaults(func=decode_sprite)

    narc_extract = subparsers.add_parser("narc-extract", help="Extract raw NARC members to files.")
    narc_extract.add_argument("--input", required=True)
    narc_extract.add_argument("--output-dir", required=True)
    narc_extract.add_argument("--members", nargs="+", required=True)
    narc_extract.add_argument("--auto-decompress-lz10", action="store_true")
    narc_extract.set_defaults(func=extract_narc_members)

    ncgr_sheet = subparsers.add_parser("ncgr-sheet", help="Render an NCGR/NCLR tile sheet to PNG.")
    ncgr_sheet.add_argument("--ncgr", required=True)
    ncgr_sheet.add_argument("--nclr", required=True)
    ncgr_sheet.add_argument("--output", required=True)
    ncgr_sheet.add_argument("--width-tiles", type=int, default=8)
    ncgr_sheet.add_argument("--transparent-index-zero", action="store_true")
    ncgr_sheet.set_defaults(func=render_ncgr_sheet)

    sdat = subparsers.add_parser("sdat-summary", help="Summarize an SDAT archive to JSON.")
    sdat.add_argument("--input", required=True)
    sdat.add_argument("--output", required=True)
    sdat.set_defaults(func=summarize_sdat)

    particle = subparsers.add_parser("scene4-particles", help="Extract scene 4 SPL particle metadata and textures.")
    particle.add_argument("--narc", required=True)
    particle.add_argument("--member", type=int, default=4)
    particle.add_argument("--output-dir", required=True)
    particle.set_defaults(func=extract_scene4_particles)

    bake_particles = subparsers.add_parser("bake-scene4-particles", help="Bake scene 4 particle metadata into deterministic native frames.")
    bake_particles.add_argument("--manifest", required=True)
    bake_particles.add_argument("--output-dir", required=True)
    bake_particles.add_argument("--seed", type=int, default=1)
    bake_particles.set_defaults(func=bake_scene4_particles)

    render_audio = subparsers.add_parser("render-audio", help="Render an SDAT sequence cue to a native WAV file.")
    render_audio.add_argument("--input", required=True)
    render_audio.add_argument("--cue-name", required=True)
    render_audio.add_argument("--output-wav", required=True)
    render_audio.add_argument("--output-json")
    render_audio.add_argument("--sample-rate", type=int, default=DEFAULT_OUTPUT_SAMPLE_RATE)
    render_audio.add_argument("--target-duration-seconds", type=float)
    render_audio.set_defaults(func=render_sequence_audio)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
