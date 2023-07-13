#pragma once

#include <cassert>
#include <cstring>
#include <climits>
#include <bit>
#include <iterator>
#include <type_traits>
#include <string_view>

namespace Rml {

constexpr bool EnumIsValid(std::string_view name) noexcept {
    for (std::size_t i = name.size(); i > 0; --i) {
        const char c = name[i - 1];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_'))) {
            name.remove_prefix(i);
            break;
        }
    }
    if (name.size() > 0) {
        const char c = name[0];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c == '_')) {
            return true;
        }
    }
    return false;
}

template <typename E, E V>
constexpr auto EnumIsValid() noexcept {
#if defined(_MSC_VER)
    return EnumIsValid({__FUNCSIG__, sizeof(__FUNCSIG__) - 17});
#else
    return EnumIsValid({__PRETTY_FUNCTION__, sizeof(__PRETTY_FUNCTION__) - 2});
#endif
}

template <typename E, std::size_t I = 0>
constexpr auto EnumCount() noexcept {
    if constexpr (!EnumIsValid<E, static_cast<E>(static_cast<std::underlying_type_t<E>>(I))>()) {
        return I;
    } else {
        return EnumCount<E, I+1>();
    }
}

template <typename E>
static constexpr auto EnumCountV = EnumCount<E>();

template <typename T>
class EnumSet {
private:
    static_assert(std::is_enum_v<T>);
    static constexpr auto N = EnumCountV<T>;
    using BitT = std::conditional_t<N <= sizeof(unsigned long) * CHAR_BIT, unsigned long, unsigned long long>;
    static constexpr ptrdiff_t Bitsperword = CHAR_BIT * sizeof(BitT);
    BitT data[(N == 0) ? 1 : ((N - 1) / Bitsperword) + 1];
public:
    class const_iterator {
    public:
        using iterator_category = std::forward_iterator_tag;
        constexpr explicit const_iterator(const EnumSet& set)
            : index { static_cast<size_t>(-1) }
            , set { set }
        {}
        constexpr const_iterator operator++() {
            seek_next();
            return *this;
        }
        constexpr const_iterator operator++(int) {
            const_iterator prev_this = *this;
            seek_next();
            return prev_this;
        }
        constexpr T operator*() const { return static_cast<T>(index); }
        constexpr bool operator==(const const_iterator& rhs) const {
            return (index == rhs.index) && (set == rhs.set);
        }
        constexpr bool operator!=(const const_iterator& rhs) const {
            return !operator==(rhs);
        }
        friend constexpr const_iterator EnumSet::begin() const;
        friend constexpr const_iterator EnumSet::end() const;
    protected:
        size_t index;
    private:
        constexpr void seek_next() {
            while (++(index) < N) {
                if (set.contains((T)index) == true) {
                    break;
                }
            }
        }
        const EnumSet& set;
    };

    constexpr EnumSet() noexcept : data() {}

    constexpr void insert(T v) {
        size_t pos = (size_t)v;
        assert(pos < N);
        data[pos / Bitsperword] |= BitT{1} << pos % Bitsperword;
    }
    constexpr void erase(T v) {
        size_t pos = (size_t)v;
        assert(pos < N);
        data[pos / Bitsperword] &= ~(BitT{1} << pos % Bitsperword);
    }
    constexpr void clear() {
        if (std::is_constant_evaluated()) {
            for (auto& e : data) {
                e = 0;
            }
        } else {
            std::memset(&data, 0, sizeof(data));
        }
    }
    constexpr bool empty() const {
        for (size_t i = 0; i < sizeof(data)/sizeof(data[0]); ++i) {
            if (data[i] != 0) {
                return false;
            }
        }
        return true;
    }
    constexpr bool contains(T v) const {
        size_t pos = (size_t)v;
        assert(pos < N);
        return (data[pos / Bitsperword] & (BitT{1} << pos % Bitsperword)) != 0;
    }
    constexpr size_t size() const {
        size_t n = 0;
        for (size_t i = 0; i < sizeof(data)/sizeof(data[0]); ++i) {
            n += std::popcount(data[i]);
        }
        return n;
    }
    constexpr EnumSet& operator&=(const EnumSet& other) {
        for (size_t i = 0; i < sizeof(data)/sizeof(data[0]); ++i) {
            data[i] &= other.data[i];
        }
        return *this;
    }
    constexpr EnumSet& operator|=(const EnumSet& other) {
        for (size_t i = 0; i < sizeof(data)/sizeof(data[0]); ++i) {
            data[i] |= other.data[i];
        }
        return *this;
    }
    constexpr bool operator==(const EnumSet& other) const {
        for (size_t i = 0; i < sizeof(data)/sizeof(data[0]); ++i) {
            if (data[i] != other.data[i]) {
                return false;
            }
        }
        return true;
    }
    constexpr EnumSet operator&(const EnumSet& other) const {
        EnumSet set = *this;
        set &= other;
        return set;
    }
    constexpr const_iterator begin() const {
        const_iterator iterator{ *this };
        iterator.seek_next();
        return iterator;
    }
    constexpr const_iterator end() const {
        const_iterator iterator{ *this };
        iterator.index = N;
        return iterator;
    }
};

}