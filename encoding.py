ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

def encode_base62(number: int) -> str:
    if number == 0:
        return ALPHABET[0]
    result = []
    while number > 0:
        number, remainder = divmod(number, 62)
        result.append(ALPHABET[remainder])
    return "".join(reversed(result))
